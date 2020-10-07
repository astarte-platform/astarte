# Astarte Device SDKs

## Introduction

Astarte Device SDKs allow connecting any device to an Astarte instance.

Astarte Device SDKs are ready to use libraries that provide communication and pairing primitives.

Astarte Device SDKs should not be confused with client SDKs, hence they are not meant for client to
device communications, instead for that purpose an optional Astarte Client SDK (such as
`astarte-go`) might be used as an abstraction layer on top of existing APIs.

Under the hood Astarte Device SDKs make use of MQTT, BSON, HTTP, persistence and crypto libraries
to implement [Astarte MQTT v1 Protocol](080-mqtt-v1-protocol.html) and all the other
useful features.

An SDK is not required to connect an application to Astarte using MQTT, but it enables
rapid development and a pleasant developer experience.

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
employed therefore only changed properties are synchronized.

This feature is not available yet on Elixir, Go and Python SDKs and might be not avilable on other
SDKs with no session_present support.

### Data Validation

Astarte Device SDKs take care of data validation before sending any data, hence errors are reported
locally on the device improving troubleshooting experience.

This feature is not available yet on ESP32 and Python and might be not avilable on other platforms
with constrained resources.

## Device Registration

### device id

### Agent

### Device Unregistration

## Declaring interfaces / Introspection

## Streaming data

All Astarte Device SDKs have a primitive for sending data to a remote Astarte instance.

Following examples show how to send a value that will be inserted into "/test0/value" time series
which is defined by "/%{sensor_id}/value" parametric endpoint (that is part of
"org.astarte-platform.genericsensors.Values" interface).

C (ESP32):
```c
struct timeval tv;
gettimeofday(&tv, NULL);
uint64_t ts = tv->tv_sec * 1000 + tv->tv_usec / 1000;

astarte_err_t err = astarte_device_stream_double_with_timestamp(device, "org.astarte-platform.genericsensors.Values", "/test0/value", value, ts, 0);
```

C++ (Qt5):
```c++
m_sdk->sendData("org.astarte-platform.genericsensors.Values", "/test0/value", value, QDateTime::currentDateTime());
```

Elixir:
```elixir
Device.send_datastream(pid, "org.astarte-platform.genericsensors.Values", "/test0/value", value, timestamp: DateTime.utc_now())
```

Go:
```go
d.SendIndividualMessageWithTimestamp("org.astarte-platform.genericsensors.Values", "/test0/value", value, time.Now())
```

Java:
```java
valuesInterface.streamData("/test0/value", value, DateTime.now());
```

Python:
```python
device.send("org.astarte-platform.genericsensors.Values", "/test0/value", value, timestamp=datetime.now())
```

### Using Object Aggregated Interfaces

Following example shows how to send a value for an object aggregated interface.
In this example lat and long will be sent together and they will accessible using the REST API as a
JSON object.

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

valuesInterface.streamData("/coords", coords, DateTime.now());
```

Python:
```python
coords = {'lat': 45.409627, 'long': 11.8765254}
device.send_aggregate("com.example.GPS", "/coords", coords, timestamp=datetime.now())
```

## Setting and Unsetting Properties

## Receiving data

### Handling property unset
