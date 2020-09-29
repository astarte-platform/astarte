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
