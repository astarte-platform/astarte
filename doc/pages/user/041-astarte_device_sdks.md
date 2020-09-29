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

### Using Object Aggregated Interfaces

## Setting and Unsetting Properties

## Receiving data

### Handling property unset
