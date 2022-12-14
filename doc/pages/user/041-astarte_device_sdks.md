# Astarte Device SDKs

## Introduction

Astarte Device SDKs are ready to use libraries that provide communication and pairing primitives.
They allow to connect any device to an Astarte instance.
While an SDK is not strictly required to connect an application to Astarte using MQTT, it enables
rapid development and a pleasant developer experience.

Astarte Device SDKs should not be confused with client SDKs, as they are not meant for client to
device communications. If one is interested in an abstraction layer on top of existing APIs instead,
an optional Astarte Client SDK (such as [`astarte-go`](https://github.com/astarte-platform/astarte-go)) 
is to be used.

Under the hood Astarte Device SDKs make use of MQTT, BSON, HTTP, persistence and crypto libraries
to implement [Astarte MQTT v1 Protocol](080-mqtt-v1-protocol.html) and all the other
useful features.

They can be easily integrated into new or existing IoT projects written in any of the supported
languages or platforms.
At the moment the following SDKs are available:
* C
  * ESP32: [astarte-device-sdk-esp32](https://github.com/astarte-platform/astarte-device-sdk-esp32)
* C++
  * Qt5: [astarte-device-sdk-qt5](https://github.com/astarte-platform/astarte-device-sdk-qt5)
* Elixir: [astarte-device-sdk-elixir](https://github.com/astarte-platform/astarte-device-sdk-elixir)
* Go: [astarte-device-sdk-go](https://github.com/astarte-platform/astarte-device-sdk-go)
* Java
  * Android: [astarte-device-sdk-java](https://github.com/astarte-platform/astarte-device-sdk-java)
  * Generic: [astarte-device-sdk-java](https://github.com/astarte-platform/astarte-device-sdk-java)
* Python: [astarte-device-sdk-python](https://github.com/astarte-platform/astarte-device-sdk-python)
* Rust: [astarte-device-sdk-rust](https://github.com/astarte-platform/astarte-device-sdk-rust)

Further languages and platforms will be supported in the near future.
[Requests for new SDKs](https://github.com/astarte-platform/astarte/issues) are welcome.

## SDKs Features

### MQTT Connection

Astarte Device SDKs make use of platform specific MQTT libraries and they hide all MQTT connection
management details, including smart reconnection (randomized reconnection backoff is used).

### Device ID Generation

Some of the Astarte Device SDKs (such as the ESP32) offer optional device id generation utils that
can use the hardware id as seed.

### Automatic Registration (Agent)

Astarte Device SDKs can provide an optional automatic registration mechanism that can be used on the
field, avoiding any manual data entry or additional operations.
This optional component can be disabled when performing registration during manufactoring process.

### Client SSL Certs Request and Renewal

Astarte Device SDKs make use of short lived SSL certificates which are automatically renewed before
their expiration.

Astarte Device SDKs take care of the complete process from the certificate generation to the
certificate signing request.

### Data Serialization and Protocol Management

MQTT payloads are format agnostic, hence a serialization format should be used before transmitting
data. For this specific purpose Astarte makes use of [BSON](http://bsonspec.org/) format which
easily maps to JSON.

Astarte Device SDKs take care on user behalf of data serialization to BSON.
Last but not least some additional signaling messages are exchanged such as the introspection,
Astarte Device SDKs take care of automatically sending them and applying data compression when
necessary.

### Data Persistence and Automatic Retransmission

Astarte Device SDKs allow configuring persitence and reliability policies. In case of connection
loss data is stored to memory or disk (according to mappings configuration) and they are
automatically retransmitted as soon as the device is back online.

This feature is not available yet on Elixir, ESP32, Go and Python SDKs and might be not avilable on
other platforms with constrained resources.

### Smart Properties Sync

Astarte has support for the concept of properties, which are kept synchronized between the server
and the device.

Thanks to the [Astarte MQTT v1 Protocol](080-mqtt-v1-protocol.html) an incremental approach is
employed therefore only changed properties are synchronized. This feature is not available yet on 
Elixir, Go and Python SDKs and might be not avilable on other SDKs with no `session_present` support.

### Data Validation

Astarte Device SDKs take care of data validation before sending any data, hence errors are reported
locally on the device improving troubleshooting experience.

This feature is not available yet on ESP32 and is WIP on Rust and Python.

## Device Registration

A device must be registered beforehand to obtain its `credentials-secret`.
While there are some manual options (such as using the [`astartectl`](https://github.com/astarte-platform/astartectl) command
or using the [`Astarte Dashboard`](015-astarte_dashboard.html)),
almost all Astarte Device SDKs allow to programmatically register a Device. 
For Go you can use the [astarte_go](https://github.com/astarte-platform/astarte-go) client.

### Device id

Device ids are 128-bit long url-safe base64 strings without padding. They can be deterministic (UUID v5) or random (UUID v4).
UUID v5 are obtained from a namespace UUID and a payload (a string).
While all SDKs work with user-provided device ids, some also provide utilities to for UUID generation.

C (ESP32) with an unique hardware ID using device MAC address and other identification bits:
```c
// deterministic id
astarte_err_t astarte_hwid_get_id(&hw_id);
```

C++ (Qt5): not supported.

Elixir: UUIDv5 can be obtained using the [elixir_uuid library](https://github.com/zyro/elixir-uuid).
```elixir
# random id
device_id = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

#deterministic id
device_id = UUID.uuid5(namespace_uuid, payload, :raw)
            |> Astarte.Core.Device.encode_device_id()
```

Go (using the [Astarte Go Client](https://github.com/astarte-platform/astarte-go)):
```go 
// Random id
random_id, err := GenerateRandomAstarteId()

// Namespaced id
namespaced_id, err := GetNamespacedAstarteDeviceID(namespaceUuid,payload)
```

Java/Android: 
```java
// Random id
String randomID = AstarteDeviceIdUtils.generateId();

// Namespaced id
String deviceID = AstarteDeviceIdUtils.generateId(namespaceUuid, payload);
```

Python: not supported.

Rust:
```rust
/// Random id
let random_uuid = astarte_sdk::registration::generate_random_uuid();

///Namespaced id
let namespaced_id = astarte_sdk::registration::generate_uuid(namespaceUuid, &payload);
```

### Automatic Registration (Agent)
You can refer to the [Astarte API for device
registration](https://docs.astarte-platform.org/astarte/latest/api/index.html?urls.primaryName=Pairing%20API#/agent/registerDevice)
for more details.

C (ESP32):
```c
astarte_pairing_config cfg = 
{
    .base_url = &base_astarte_url;
    .jwt = &jwt_token;
    .realm = &realm;
    .hw_id = &device_id;
    .credentials_secret = &credentials_secret;
};

astarte_err_t err = astarte_pairing_register_device(&astarte_pairing_config);
```

C++ (Qt5): registration is done on device instantiation, see the next section.

Elixir: 
```elixir
{:ok, %{body: %{"data" => %{"credentials_secret" => credentials_secret}}}} = Agent.register_device(client, device_id)
```

Go (using the [Astarte Go Client](https://github.com/astarte-platform/astarte-go)): 
```go
credentials_secret, err := client.Pairing.RegisterDevice(realm, deviceID) 
```

Java/Android: 
```java
AstartePairingService astartePairingService = new AstartePairingService(pairing_url, realm);
String credentialsSecret = astartePairingService.registerDevice(jwt_token, device_id);
```

Python:
```python
credentials_secret = register_device_with_jwt_token(device_id, realm, jwt_token, pairing_base_url)
```
or 
```python
credentials_secret = register_device_with_private_key(device_id, realm, private_key_file, pairing_base_url)
```

Rust: 
```rust
    let credentials_secret =
        astarte_sdk::registration::register_device(&jwt_token, &pairing_url, &realm, &device_id)
            .await?;
```

### Device Unregistration

Unregistering a device boils down to making its credentials secret invalid.  
Just as device registration, there are manual or programmatic options. 
In all cases, you can use the astartectl command [`astartectl`](https://github.com/astarte-platform/astartectl),
the [`Astarte
Dashboard`](https://docs.astarte-platform.org/astarte/latest/015-astarte_dashboard.html)), or the
[Astarte API for device
unregistration](https://docs.astarte-platform.org/astarte/latest/api/index.html?urls.primaryName=Pairing%20API#/agent/unregisterDevice).

For Go and Elixir, you can also do this programmatically. 

C (ESP32): not supported. 

C++ (Qt5): not supported.

Elixir:
```elixir
:ok = Agent.unregister_device(client, device_id)
```

Go (using the [Astarte Go Client](https://github.com/astarte-platform/astarte-go)): 
```go
err := client.Pairing.UnregisterDevice(realm, deviceID) 
```

Java/Android: not supported.

Python: not supported.

Rust: not supported.

## Declaring interfaces / Introspection

Each device must declare the set of supported interfaces and their version. 
Astarte needs to know which interfaces the device advertises before processing any further data publish. 
This message in Astarte jargon is called introspection and it's performed by publishing on the device root topic the list of interfaces that are installed on the device.

The Astarte Device SDKs take care of performing the introspection on user behalf. 
In order to do so, the Astarte Device SDKs need to have some informations about the registered device: 
- the Astarte realm in which the device is registered
- its device id 
- its credentials_secret 
- the url of Astarte pairing service
- the path of the desired interfaces.

Then the Astarte Device SDKs will be able to connect the device to Astarte and perform introspection. 

C (ESP32):
```c
astarte_device_config_t cfg = {
    .data_event_callback = astarte_data_events_handler,
    .connection_event_callback = astarte_connection_events_handler,
    .disconnection_event_callback = astarte_disconnection_events_handler,
};

astarte_device_handle_t device = astarte_device_init(&cfg);
if (!device) {
    ESP_LOGE(TAG, "Failed to init astarte device");
    return;
}

astarte_device_add_interface(device, &device_example_interface);
if (astarte_device_start(device) != ASTARTE_OK) {
    ESP_LOGE(TAG, "Failed to start astarte device");
    return;
}
```

C++ (Qt5):
```c++
// declare device options and interfaces
m_sdk = new AstarteDeviceSDK(QDir::currentPath() + QStringLiteral("./examples/device_sdk.conf").arg(deviceId), QDir::currentPath() + QStringLiteral("./examples/interfaces"), deviceId.toLatin1());

// initialize device
connect(m_sdk->init(), &Hemera::Operation::finished, this, &AstarteStreamQt5Test::checkInitResult);

// set data handlers
connect(m_sdk, &AstarteDeviceSDK::dataReceived, this, &AstarteStreamQt5Test::handleIncomingData)
```

Elixir:
```elixir
# declare device options
opts = [pairing_url: pairing_url, realm: realm, device_id: device_id, interface_provider: "./examples/interfaces", credentials_secret: credentials_secret]

# start device and connect asynchronously
{:ok, pid} = Device.start_link(opts)

# blocking (optional)
:ok <- Device.wait_for_connection(device_pid)
```

Go:
```go
	// Create device
	d, err := device.NewDevice(deviceID, deviceRealm, credentialsSecret, apiEndpoint)
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

	// Load interface - fix this path(s) to load the right interface
	byteValue, err := ioutil.ReadFile("/examples/interfaces/com.example.Interface.json")
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}
	iface := interfaces.AstarteInterface{}
	if iface, err = interfaces.ParseInterface(byteValue); err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

	if err = d.AddInterface(iface); err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

	// Set up callbacks
	d.OnConnectionStateChanged = func(d *device.Device, state bool) {
		fmt.Printf("Device connection state: %t\n", state)
	}

	// Connect the device and listen to the connection status channel
	c := make(chan error)
	d.Connect(c)
	if err := <-c; err == nil {
		fmt.Println("Connected successfully")
	} else {
		fmt.Println(err.Error())
		os.Exit(1)
	}
```

Java:
```java
    // Device creation
    // connectionSource allows to connect to a db for persistency
    // The interfaces supported by the device are populated by ExampleInterfaceProvider
    AstarteDevice device =
        new AstarteGenericDevice(
            deviceId,
            realm,
            credentialsSecret,
            new ExampleInterfaceProvider(),
            pairingUrl,
            connectionSource);

    // ExampleMessageListener listens for device connection, disconnection and failure.
    device.setAstarteMessageListener(new ExampleMessageListener());

    // Connect the device
    device.connect();

```

Python:
```python
# declare device options
device = Device(device_id, realm, credentials_secret, pairing_base_url)

# load device interfaces
device.add_interface(json.loads("/examples/interfaces/com.example.Interface.json"))

#register a callback that will be invoked everytime the device successfully connects
device.on_connected(callback)

#connect the device asynchronously
device.connect()
```

Rust:
```rust
    /// declare device options
    let mut sdk_options =
        AstarteOptions::new(&realm, &device_id, &credentials_secret, &pairing_url);

    /// load interfaces from a directory
    sdk_options
        .add_interface_files("./examples/interfaces")
        .unwrap();

    /// build Astarte client
    sdk_options.build().await.unwrap();

    /// connect the device
    let mut device = sdk_options.connect().await.unwrap();
```

## Streaming data

All Astarte Device SDKs have a primitive for sending data to a remote Astarte instance.

### Using Individual Aggregated Interfaces
In Astarte interfaces with `individual` aggregation, each mapping is treated as an independent value 
and is managed individually.

Following examples show how to send a value that will be inserted into the `"/test0/value"` time series
which is defined by `"/%{sensor_id}/value"` parametric endpoint (that is part of
`"org.astarte-platform.genericsensors.Values"` datastream interface).

C (ESP32):
```c
struct timeval tv;
gettimeofday(&tv, NULL);
uint64_t ts = tv->tv_sec * 1000 + tv->tv_usec / 1000;

astarte_err_t err = astarte_device_stream_double_with_timestamp(device, "org.astarte-platform.genericsensors.Values", "/test0/value", 0.3, ts, 0);
```

C++ (Qt5):
```c++
m_sdk->sendData("org.astarte-platform.genericsensors.Values", "/test0/value", 0.3, QDateTime::currentDateTime());
```

Elixir:
```elixir
Device.send_datastream(pid, "org.astarte-platform.genericsensors.Values", "/test0/value", 0.3, timestamp: DateTime.utc_now())
```

Go:
```go
d.SendIndividualMessageWithTimestamp("org.astarte-platform.genericsensors.Values", "/test0/value", 0.3, time.Now())
```

Java:
```java
genericSensorsValuesInterface.streamData("/test0/value", 0.3, DateTime.now());
```

Python:
```python
device.send("org.astarte-platform.genericsensors.Values", "/test0/value", 0.3, timestamp=datetime.now())
```

Rust
```rust
device.send_with_timestamp("org.astarte-platform.genericsensors.Values", "/test0/value", 3, chrono::offset::Utc::now()).await?;
```

### Using Object Aggregated Interfaces
In Astarte interfaces with `object` aggregation, Astarte expects the owner to send all of the interface's mappings 
at the same time, packed in a single message. In this case, all of the mappings share some core properties.

Following examples show how to send a value for an object aggregated interface.
In this examples, `lat` and `long` will be sent together and will be inserted into the `"/coords"` time series
which is defined by `"/coords"` endpoint (that is part of `"com.example.GPS"` datastream interface).

C (ESP32):
```c
astarte_bson_serializer_init(&bs);
astarte_bson_serializer_append_double(&bs, "lat", 45.409627);
astarte_bson_serializer_append_double(&bs, "long", 11.8765254);
astarte_bson_serializer_append_end_of_document(&bs);
int size;
const void *coord = astarte_bson_serializer_get_document(&bs, &size);

struct timeval tv;
gettimeofday(&tv, NULL);
uint64_t ts = tv->tv_sec * 1000 + tv->tv_usec / 1000;

astarte_device_stream_aggregate_with_timestamp(device, "com.example.GPS", "/coords", coords, ts, 0);
```

C++ (Qt5):
```c++
QVariantHash coords;
coords.insert(QStringLiteral("lat"), 45.409627);
coords.insert(QStringLiteral("long"), 11.8765254);
m_sdk->sendData("com.example.GPS", "/coords", coords, QDateTime::currentDateTime());
```

Elixir:
```elixir

coords = %{lat: 45.409627, long: 11.8765254}
Device.send_datastream(pid, "com.example.GPS", "/coords", coords, timestamp: DateTime.utc_now())
```

Go:
```go
coords := map[string]double{"lat": 45.409627, "long": 11.8765254}
d.SendAggregateMessageWithTimestamp("com.example.GPS", "/coords", coords, time.Now())
```

Java:
```java

Map<String, Double> coords = new HashMap<String, Double>()
{
    {
        put("lat", 45.409627);
        put("long", 11.8765254);
    }
};

exampleGPSInterface.streamData("/coords", coords, DateTime.now());
```

Python:
```python
coords = {'lat': 45.409627, 'long': 11.8765254}
device.send_aggregate("com.example.GPS", "/coords", coords, timestamp=datetime.now())
```

Rust: 
```rust
/// Coords must implement the Serializable trait
let coords = Coords{lat:  45.409627, long: 11.8765254};
device.send_object_with_timestamp("com.example.GPS", "/coords", coords, chrono::offset::Utc::now()).await?;
```

### Setting and Unsetting Properties
`properties` represent a persistent, stateful, synchronized state with no concept of history or timestamping.
From a programming point of view, setting and unsetting properties of device-owned interface is rather similar to sending messages on datastream interfaces.

Following examples show how to send a value that will be inserted into the `"/sensor0/name"` property
which is defined by `"/%{sensor_id}/name"` parametric endpoint (that is part of
`"org.astarte-platform.genericsensors.AvailableSensors"` device-owned properties interface).


C (ESP32):
```c
// set property (one function for each type)
astarte_device_set_string_property(device, "org.astarte-platform.genericsensors.AvailableSensors", "/sensor0/name", "foobar");

// unset property
astarte_device_unset_path(device, "org.astarte-platform.genericsensors.AvailableSensors", "/sensor0/name");
```

C++ (Qt5):
```c++
// set property (same as datastream)
m_sdk->sendData(m_interface, m_path, value, QDateTime::currentDateTime());

// unset property
m_sdk->sendUnset(m_interface, m_path);
```

Elixir:
```elixir
# set property (same as datastream)
Device.set_property(pid, "org.astarte-platform.genericsensors.AvailableSensors", "/sensor0/name", "foobar")

# unset property
Device.unset_property(pid, "org.astarte-platform.genericsensors.AvailableSensors", "/sensor0/name")
```

Go: 
```go
// set property
d.SetProperty("org.astarte-platform.genericsensors.AvailableSensors", "/sensor0/name", "foobar")

// unset property
d.UnsetProperty("org.astarte-platform.genericsensors.AvailableSensors", "/sensor0/name")
```

Java:
```java
// set property
availableSensorsInterface.setProperty("/sensor0/name", "foobar");

// unset property
propertyInterface.unsetProperty("/sensor0/name");
```

Python:
```python
# set property (same as datastream)
device.send("org.astarte-platform.genericsensors.AvailableSensors", "/sensor0/name", "foobar")

# unset property
device.unset_property("org.astarte-platform.genericsensors.AvailableSensors", "/sensor0/name")
```

Rust: 
```rust
/// set property (same as datastream)
device.send("org.astarte-platform.genericsensors.AvailableSensors", "/sensor0/name", "foobar");

/// unset property
device.unset("org.astarte-platform.genericsensors.AvailableSensors", "/sensor0/name");
```
