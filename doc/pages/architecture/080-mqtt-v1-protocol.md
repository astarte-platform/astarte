# Astarte MQTT v1 Protocol

Astarte MQTT v1 Protocol allows communication between Astarte and devices. It is the first protocol that has been implemented in Astarte, and it exploits every feature provided by Astarte itself. Astarte MQTT v1 doesn't mandate a specific Transport Credentials format: the broker must handle Authentication, Authorization and [Pairing integration](050-pairing_mechanism.html) the way it sees fit. Astarte MQTT v1 is implemented by Astarte's Reference Transport, [Astarte/VerneMQ](https://github.com/astarte-platform/astarte_vmq_plugin) - a client wishing to interact with it must implement MQTT v3.1.1 and all needed features for Pairing to work.

MQTT doesn't mandate the data serialization format, so any application might implement its own format. Data serialization might be a tricky task and protocols might be hard to design, Astarte MQTT takes care of this and provides a higher level protocol which abstracts this detail from the end user.

Astarte MQTT v1 Protocol builds upon MQTT v3.1.1 itself, [BSON](http://bsonspec.org/spec.html) (Binary JSON, version 1.1) serialized payloads and on optional zlib deflate. All communications are ordered and asynchronous.

A protocol reference implementation is provided with an Astarte SDK, however developers might implement it from scratch using 3rd party libraries with their favourite languages: all formats and protocols described here are open and well documented. Last but not least Astarte doesn't mandate this protocol, and a different one can be used with a different transport.

## MQTT Topics Overview

Astarte MQTT v1 Protocol relies on few well known reserved topics.

| Topic                                                  | Purpose          | Published By | QoS     | Payload Format                          |
|--------------------------------------------------------|------------------|--------------|---------|-----------------------------------------|
| `<realm name>/<device id>`                             | Introspection    | Device       | 2       | ASCII plain text, ':' and ';' delimited |
| `<realm name>/<device id>/control/emptyCache`          | Empty Cache      | Device       | 2       | ASCII plain text (always "1")           |
| `<realm name>/<device id>/control/consumer/properties` | Purge Properties | Astarte      | 2       | deflated plain text                     |
| `<realm name>/<device id>/control/producer/properties` | Purge Properties | Device       | 2       | deflated plain text                     |
| `<realm name>/<device id>/<interface name>/<path>`     | Publish Data     | Both         | 0, 1, 2 | BSON (or empty)                         |

For clarity reasons all `<realm name>/<device id>` prefixes will be omitted on the following paragraphs, those topics will be called device topics.
Topics are not bidirectional, devices must not publish data for server owned topics and viceversa, onwership is explicitly stated in interfaces files.

## BSON

BSON allows saving precious bytes compared to JSON, while offering the advantages of a schema-less protocol.
Consider, for example, a simple value and timestamp payload. The encoded JSON version, `{"v":25.367812,"t":1537346756844}` counts 33 bytes.

The hexdump of the same message encoded with BSON is:
```
0000000 1b 00 00 00 09 74 00 ec e0 01 f1 65 01 00 00 01
0000020 76 00 8c 13 5f ed 28 5e 39 40 00
```

that fits just in 27 bytes.

### BSON format

BSON is a really simple binary format, breaking down the previous example is very easy thanks to BSON simplicity: the first 4 bytes (`1b 00 00 00`) are the document size header, follows the timestamp marker (`09`), the timestamp key name (`74 00`, that is "t"), the timestamp value (`5f 48 06 f1 65 01 00 00` as int64), the double value marker (`01`),  the value key name (`76 00`, that is "v"), the actual value (`cd cc cc cc cc 4c 39 40` as 64-bit IEEE 754-2008 floating point) and the end of document marker (`00`).

### Astarte payload standard fields

| Key | Type             | Mandatory | Description                                                |
|-----|------------------|-----------|------------------------------------------------------------|
| v   | Any Astarte type | Yes       | The value being sent (both properties and datastream)      |
| t   | UTC datetime     | No        | Explicit timestamp, if present (optional, datastream only) |

### Astarte data types to BSON types

| Astarte Data Type | BSON Type           | Size in Bytes                                      |
|-------------------|---------------------|----------------------------------------------------|
| double            | double (0x01)       | 8                                                  |
| integer           | int32 (0x10)        | 4                                                  |
| boolean           | boolean (0x08)      | 1                                                  |
| longinteger       | int64 (0x12)        | 8                                                  |
| string            | UTF-8 string (0x02) | >= length (encoding dependent)                     |
| binaryblob        | binary (0x05)       | length                                             |
| datetime          | UTC datetime (0x09) | 8                                                  |
| doublearray       | Array (0x04)        | (8 + keysize) * count                              |
| integerarray      | Array (0x04)        | (4 + keysize) * count                              |
| booleanarray      | Array (0x04)        | (1 + keysize) * count                              |
| longintegerarray  | Array (0x04)        | (1 + keysize) * count                              |
| stringarray       | Array (0x04)        | depends on count, length, keys length and encoding |
| binaryblobarray   | Array (0x4)         | depends on count, keys length and length           |

`integer` and `long` integer are signed integer values, double must be a valid number (`+inf`, `NaN`, etc... are not supported), variable data types might be subject to size limitations and object aggregations are encoded as embedded documents.

## Connection and Disconnection

A device is not required to publish any additional connection or disconnection messages, the MQTT broker will automatically keep track of these events and relay them to Astarte.
When connecting, before publishing any data message, a device should check MQTT *session present* flag. When the MQTT *session present* flag is *true* no further actions are required, when *false* the device should take following actions:

* Publish its introspection
* Publish an empty cache message
* Publish all of its existing and set properties on all its property interfaces

If a device is unable to inspect *session present* all previous actions must be taken at every reconnection.

## Introspection

Each device must declare the set of supported interfaces and their version. Astarte needs to know which interfaces the device advertises before processing any further data publish.
This message in Astarte jargon is called *introspection* and it's performed by publishing on the device root topic the list of interfaces that are installed on the device.

Introspection payload is a simple plain text string, and it has the following format (in BNF like syntax):

```
introspection ::= introspection_list
introspection_list ::= introspection_entry ";" introspection_list | introspection_entry
introspection_entry ::= interface_name ":" interface_major_version ":" interface_minor_version
```

The following example is a valid introspection payload:

```
com.example.MyInterface:1:0;org.example.DraftInterface:0:3
```

## Empty Cache
Astarte MQTT v1 strives to save bandwidth upon reconnections, to make sure even frequent reconnections don't affect bandwidth consumption. As such, upon connecting and if MQTT advertises a session present, both sides assume that data flow is ordered and consistent. However, there might be cases where this guarantee isn't respected by the device for a number of reasons (e.g.: new device, factory reset, cache lost...). In this case, a device might declare that it has no confidence about its status and its known properties, and can request to resynchronise entirely with Astarte.
In Astarte jargon this message is called *empty cache* and it is performed by publising "1" on the device `/control/emptyCache` topic.

After an empty cache message properties might be purged and Astarte might publish all the server owned properties again.

## Session Present

In the very same fashion as the device, Astarte (or the broker) might be inconsistent with a Device's known status and its known properties. Although unlikely, as Astarte should always keep knowledge about remote device status, this might happen, for example, after an internal error.
Astarte performs this task by telling the broker to disconnect the device and clear its session. After this, when the device will attempt reconnection, session present will be false.

After a clean session properties might be purged.

## Purge Properties

Either a Device or Astarte may tell the remote host the set properties list. Any property that is not part of the list will be deleted from any cache or database.
This task is called _purge properties_ in Astarte jargon, and it is performed by publishing a the list of known set properties to `/control/consumer/properties` or `/control/producer/properties`.

Purge Properties payload is a zlib deflated plain text, with an additional 4 bytes header.
The additional 4 bytes header is the size of the uncompressed payload, encoded as big endian uint32.

The following example is a payload compressed using zlib default compression, with the additional 4 bytes header:
```
0000000 00 00 00 46 78 9c 4b ce cf d5 4b ad 48 cc 2d c8
0000020 49 d5 f3 ad f4 cc 2b 49 2d 4a 4b 4c 4e d5 2f ce
0000040 cf 4d d5 2f 48 2c c9 b0 ce 2f 4a 87 ab 70 29 4a
0000060 4c 2b 41 28 ca 2f c9 48 2d 0a 00 2a 02 00 b2 0c
0000100 1a c9
```

The uncompressed plain text payload has the following format (in BNF like syntax):

```
properties ::= properties_list
properties_list ::= properties_entry ";" properties_list | properties_entry
properties_entry ::= interface_name path
```

The following example is the inflated previous payload:

```
com.example.MyInterface/some/path;org.example.DraftInterface/otherPath
```

This protocol feature is fundamental when a device has any interface with an *allow_unset* mapping, *purge properties* allows to correct any error due to unhandled unset messages.

## Publishing Data

Either Astarte or a device might publish new data on a interface/endpoint specific topic.
The topic is built using `/<interface name>/<path>` schema, and it is used regardless of the type of interface or mapping being used.

Also `/` path is a valid path for object aggregated interfaces.

The following device topics are valid:

* `/com.example.MyInterface/some/path`
* `/org.example.DraftInterface/otherPath`
* `/com.example.astarte.ObjectAggregatedInterface/`

Data messages QoS is chosen according to mapping settings, such as reliability. Properties are always published using QoS 2.

| Interface Type | Reliability     | QoS |
|----------------|-----------------|-----|
| properties     | always unique   | 2   |
| datastream     | unreliable      | 0   |
| datastream     | guaranteed      | 1   |
| datastream     | unique          | 2   |

### Payload Format

Payload format might change according to the message type. Payloads are always BSON encoded, except for unset messages that are empty.

#### Property Message

Property messages have a ["v" key](#astarte-payload-standard-fields) (which means value). Valid examples are:

* `{"v": "string property value"}`
* `{"v": 10}`
* `{"v": true}`

Previous payloads are BSON encoded as the following hex dumps:

```
0000000 22 00 00 00 02 76 00 16 00 00 00 73 74 72 69 6e
0000020 67 20 70 72 6f 70 65 72 74 79 20 76 61 6c 75 65
0000040 00 00
```

```
0000000 0c 00 00 00 10 76 00 0a 00 00 00 00
```

```
0000000 09 00 00 00 08 76 00 01 00
```

Property messages order must be preserved and they must be consumed in order. The same property with the same value can be sent several times, this behavior is allowed but discouraged: it's up to the device to avoid useless messages.
A device must also make sure to publish all the properties that have been changed while the device was offline.

#### Unset Property Message

Properties can be unset with an unset message. An unset message is just an empty 0 bytes payload.

#### Datastream Message (individual aggregation)

Datastream messages for interfaces with individual aggregation have a ["v" key](#astarte-payload-standard-fields) and an optional ["t" key](#astarte-payload-standard-fields) (which means timestamp). Valid examples are:

* `{"v": false}`

* `{"v": 16.73}`

* `{"v": 16.73, "t": 1537449422890}`

Timestamps are UTC timestamps (BSON 0x09 type), when not provided reception timestamp is used.

Previous payloads are BSON encoded as the following hex dumps:

```
0000000 09 00 00 00 08 76 00 00 00
```

```
0000000 10 00 00 00 01 76 00 7b 14 ae 47 e1 ba 30 40 00
```

```
0000000 1b 00 00 00 09 74 00 2a 70 20 f7 65 01 00 00 01
0000020 76 00 7b 14 ae 47 e1 ba 30 40 00
```

#### Datastream Message (object aggregation)

Datastream messages for interfaces with object aggregation support every Astarte payload standard field (such as "t"), but in this case _value_ is a BSON subdocument, in which each key represent a mapping of the aggregation. Valid examples are:

* `{"v": {"temp": 25.3123, "hum": 67.112}}`

* `{"v": {"temp": 25.3123, "hum": 67.112}, "t": 1537452514811}`

Timestamps are UTC timestamps (BSON 0x09 type), when not provided reception timestamp is used.

Previous payloads are BSON encoded as following hex dumps:

```
0000000 28 00 00 00 03 76 00 20 00 00 00 01 68 75 6d 00
0000020 ba 49 0c 02 2b c7 50 40 01 74 65 6d 70 00 72 8a
0000040 8e e4 f2 4f 39 40 00 00
```

```
0000000 33 00 00 00 09 74 00 fb 9d 4f f7 65 01 00 00 03
0000020 76 00 20 00 00 00 01 68 75 6d 00 ba 49 0c 02 2b
0000040 c7 50 40 01 74 65 6d 70 00 72 8a 8e e4 f2 4f 39
0000060 40 00 00
```

## Minimal Protocol

A device might implement a subset of this protocol if needed. `/control/consumer/properties`, `/control/producer/properties` and `/emptyCache` might be ignored or not implemented if a device has no property interfaces.
A further simplification might remove any requirement for any introspection message when previously provisioned, but this feature is not supported out of the box.

## Error Handling

A device might be forcefully disconnected due to any kind of error. Devices should wait a random amount of time before trying to connect again to the broker.
_session present_ might be also set to false to ensure a clean and consistent state (in that case messages such as _introspection_ and _empty cache_ should published as previously described).

Malformed or unexpected messages are discarded and further actions might be taken.

## Authentication
In Astarte, every Transport orchestrates its credentials through Pairing. Astarte/VerneMQ authenticates devices using Mutual SSL Autentication - as such, devices use SSL certificates emitted through [Pairing API](050-pairing_mechanism.html) to authenticate against the broker. To achieve this, the device must ensure it is capable of performing http(s) calls to Pairing API to obtain its certificates, performing SSL/X509 operations and connecting to the MQTT Broker through the use of SSL certificates.

## Authorization
Device can only publish and subscribe to its device topic (`<realm name>/<device id>`) and its subtopics. The broker will deny any publish or subscribe outside that hierarchy.

## Connecting to the Broker

In the same fashion as Authentication, Pairing provides the client with information about how to connect to the MQTT broker. When invoking relevant Pairing API's method to gather information about available transports for a device, if Astarte advertises Astarte MQTT v1, a similar reply will be returned:

```
{
  "data": {
    "version": "<version string>",
    "status": "<status string>",
    "protocols": {
      "astarte_mqtt_v1": {
        "broker_url": "mqtts://broker.astarte.example.com:8883"
      }
    }
  }
}
```
