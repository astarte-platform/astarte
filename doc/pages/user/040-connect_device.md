# Connecting a Device

Once a Device has been Registered in Astarte, it is capable of connecting to it.

Devices connect to Astarte through the use of *Transports*. A Transport is an arbitrary protocol
implementation which maps Astarte's concepts (mainly Interfaces) to a communication channel.
Astarte's main supported Transport is Astarte/MQTT, implemented on top of
[VerneMQ](https://github.com/erlio/vernemq) through [an additional
plugin](https://github.com/astarte-platform/astarte_vmq_plugin), and it is used by Astarte's SDKs
for communication. However, virtually any protocol can be integrated in Astarte by creating a
corresponding Transport.

Transports also define the authentication/authorization mechanism of their Devices. For instance,
Astarte/MQTT uses [mutual SSL Authentication](https://en.wikipedia.org/wiki/Mutual_authentication)
with Certificate Rotation for securing its Ingress and identifying its clients. To manage their
Transport(s) and Credentials, Devices have to interact with Pairing.

## Credentials Secret, Pairing and Transports

Once a Device has performed its first registration through an Agent, it holds its *Credentials
Secret*. This *Credentials Secret* is the token the device uses for performing the actual Pairing
routine, which results in the device obtaining its Credentials for accessing its designated
Transport.

A Device's *Credentials Secret* allows access to [Pairing API's Device REST
API](https://docs.astarte-platform.org/snapshot/api/?urls.primaryName=Pairing%20API#/device), which
is then used for obtaining information about which Transports the Device can use for communicating,
and for obtaining Credentials for its assigned Transports.

The ability to request Credentials of a Device can be inhibited with [AppEngine
API](/api/#/device/updateDeviceStatus) or using
[`astartectl`](https://github.com/astarte-platform/astartectl) with this command:

```
astartectl appengine devices credentials inhibit <device_id_or_alias> true \
  -k <appengine-key> -r <realm-name> -u <astarte-api-url>
```

Once its `credentials_inhibited` field is set to `true`, a Device is not able to request new
Credentials. Note that Credentials that were already emitted will still be valid until their
expiration.

As, from a user's standpoint, the way a Device communicates with Astarte is entirely
Transport-specific, this guide will cover using Astarte/MQTT through one of Astarte's SDKs. If you
are using a different Transport, please refer to its User Guide, or if you wish to implement your
own, head over to [Transport Developer Documentation]().

## Using Astarte/MQTT through Astarte SDK

If you are using one of Astarte's SDK, the Pairing routine is entirely managed, and you won't need
to do any of the aforementioned steps. Just make sure your *Credentials Secret* is passed as the
`apiKey` configuration key, to allow the SDK to perform automatically the Pairing routine when
needed.

The SDK does a number of automated things under the hood. Its flow is:

1. The SDK verifies if a SSL certificate for connecting to the broker is present.
2. If it is, it attempts connecting to the Transport.
3. If the Transport doesn't accept the connection due to an SSL error, it queries Pairing API about
   its certificate status.
4. If Pairing API returns a problem with the certificate or, in general, the certificate isn't
   valid, the certificate is erased and the Pairing procedure begins.
5. The SDK invokes Pairing API until it manages to obtain a valid Certificate for the Transport.

The SDK considers a Device successfully paired when it has a valid certificate and manages to
connect to the Transport. Once in this state, the Device can start exchanging data.

*Note: the Pairing procedure is secure as long as Pairing API is queried using HTTPS. Plain HTTP
installations are vulnerable to a number of different attacks and should NEVER be used in
production.*

### Interfaces and Introspection

A Device **must** have some installed interfaces to be capable of exchanging data. These interfaces
must be made known to the SDK and [installed in the Device's Realm, as previously
explained](030-manage_interfaces.html#realm-vs-device-interface-relationship).

The SDK expects the user to provide a directory containing a set of valid interfaces. It then takes
care of making Astarte aware of its registered interfaces through a process called Introspection.
Introspection is a special control message in Astarte's protocol which makes Astarte aware of a list
of Interfaces and relative versions which are installed on the Device.

Again, Astarte's SDK, given a directory, is capable of performing the correct procedures for keeping
Introspecting in sync correctly without any kind of user intervention. Astarte's SDK also takes care
of updating a Device's Introspection if its interfaces change.

### Exchanging data

When a Device connects successfully, it **must** then subscribe to its `server` Interfaces. The SDK
takes care of this detail and exposes a higher level interface. For example, using the Qt5 SDK:

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

Applications can simply connect to the `handleIncomingData` signal and have data correctly formatted
and delivered as it runs through the transport. On the other hand, for sending data:

```
m_sdk->sendData(interface, path, value);
```

The SDK will check if data is coherent with its introspection, and send data onto the transport in
the correct way.

### Reliability, retention and persistency in the SDK

Astarte's SDK has an internal concept of persistency, depending on the behaviour defined in its
installed Interfaces. The `retention` parameter, specifically, tells Astarte's SDK how hard it
should try to send a specific message. In case the Transport is unreachable, the SDK might try to
persist, either in memory or on disk, and send the message when the connection is available again.

Please note that these parameters declared in Interfaces are to be considered on a best effort
basis. In case your SDK does not support persistency or has persistency disabled, a number of
warranties requested by an Interface might not be satisfied. Make sure your SDK is configured
correctly before moving to production.
