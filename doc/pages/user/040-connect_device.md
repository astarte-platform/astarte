# Connect a Device

Devices connect to Astarte through their designated Transport. 

## Choosing an Agent mode

Before you begin connecting, you have to choose a Pairing mode for your realm. This will define how your devices will perform the first Pairing routine against your Realm.

Please also note that you might choose to have a mixture of both mechanisms, even though this is definitely not a good idea in production.

### On Board Agent

*Please keep in mind that the On Board Agent mechanism is not advised in production, as a single compromised device/token might compromise the Pairing routine for your entire fleet. It should be used only in non-critical use cases or during testing and development.*

When using a On Board Agent, you're assuming you're either unable or not willing to use a 3rd party for delivering the API Key to each one of your devices. Although this is a big compromise on security, it allows to deliver a shared secret among all devices.

To create a On Board Agent, you simply need to emit a long-enough lived token from your SSO with Agent access to your realm (note: this part is in development and might be changed soon). This token should then be delivered to your devices.

Once your device is knowledgeable about your token, you can use Astarte SDK to start the On Board Agent Pairing. This is done and managed automatically by the SDK, as long as you set the `agentKey` configuration key to a meaningful value, and no API Key has been set.

### 3rd Party Agent

If you plan on getting your devices ready for production, you need a 3rd party agent to perform the first steps of the pairing routine. This is to prevent your devices from carrying any secret which could be used to authenticate and identify anything if not themselves.

There are no strict requirements on how an Agent should be built. In Astarte's terminology, an Agent is capable of authenticating against Pairing API with an `Agent` role. As such, it can be implemented in the most suitable way for one's use case: in its simplest form, it is an authenticated REST call to Astarte's APIs and a subsequent manual insertion of the returned API Key in the device. Please refer to the API documentation for further details.

## API Key and Pairing

Once a Device has performed its first registration through an Agent, it holds an API Key. This API Key is the token the device uses for performing the actual Pairing routine, which results in the device obtaining its Certificate. The API Key doesn't rotate, it can't be changed if not manually and identifies univocally a Device in a Realm.

In the SDK, make sure your API Key is passed as the `apiKey` configuration key, to allow the SDK to perform automatically the Pairing routine when needed.

The SDK does a number of automated things under the hood. Its flow is:

1. The SDK verifies if a SSL certificate is present.
2. If it is, it attempts connecting to the transport.
3. If the transport doesn't accept the connection due to an SSL error, it queries Pairing API about its certificate status.
4. If Pairing API returns a problem with the certificate or, in general, the certificate isn't valid, the certificate is erased and the Pairing procedure begins.
5. The SDK invokes Pairing API until it manages to obtain a valid Certificate for its Transport.

The SDK considers a Device successfully paired when it has a valid certificate and manages to connect to the Transport. Once in this state, the Device can start exchanging data.

*Note: the Pairing procedure is secure as long as Pairing API is queried using HTTPS. Plain HTTP installations are vulnerable to a number of different attacks and are not supported.*

## Interfaces

A Device **must** have some installed interfaces to be capable of exchanging data. These interfaces must be made known to the SDK and [installed in the Device's Realm, as previously explained](030-manage_interfaces.html#realm-vs-device-interface-relationship).

The SDK expects the user to provide a directory containing a set of valid interfaces. It then takes care of making Astarte aware of its registered interfaces through a process called Introspection. Introspection is a special control message in Astarte's protocol which makes Astarte aware of a list of Interfaces and relative versions which are installed on the Device.

Again, Astarte's SDK, given a directory, is capable of performing the correct procedures for keeping Introspecting in sync correctly.

## Exchanging data

When a Device connects successfully, it **must** subscribe to its `server` Interfaces. The SDK takes care of this detail and exposes a higher level interface. For example, using the Qt5 SDK:

```
{
	m_sdk = new AstarteDeviceSDK(QStringLiteral("/path/to/transport-astarte.conf"), QStringLiteral("/path/to/interfaces"), deviceId);
    connect(m_sdk->init(), &Hemera::Operation::finished, this, &AstarteStreamQt5Test::checkInitResult);
    connect(m_sdk, &AstarteDeviceSDK::dataReceived, this, &AstarteStreamQt5Test::handleIncomingData);
}

void AstarteStreamQt5Test::handleIncomingData(const QByteArray &interface, const QByteArray &path, const QVariant &value)
{
    qDebug() << "Received data, interface: " << interface << "path: " << path << ", value: " << value << ", Qt type name: " << value.typeName();
}
```

Applications can simply connect to the `handleIncomingData` signal and have the data correctly formatted and delivered as it runs through the transport. On the other hand, for sending data:

```
m_sdk->sendData(interface, path, value);
```

The SDK will check if data is coherent with its introspection, and send data onto the transport in the correct way.

## Reliability, retention and persistency in the SDK

Astarte's SDK has an internal concept of persistency, depending on the behaviour defined in its installed Interfaces. The `retention` parameter, specifically, tells Astarte's SDK how hard it should try to send a specific message. In case the Transport is unreachable, the SDK might try to persist, either in memory or on disk, and send the message when the connection is available again.
