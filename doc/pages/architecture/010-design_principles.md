# Design Principles

Astarte has a strongly opinionated design aimed at the generic IoT / data-driven use case. As such, and unlike other platforms, it strives to streamline a very simple user workflow for ingesting, distributing and retrieving data, built on a set of concepts and principles.

## Declarative vs. Explicit Data Management

Astarte does not allow exchanging raw data - it rather forces the user to describe data _before_ it is sent into the platform.

Data is described with a mechanism named [Interfaces, explained in detail in the user guide](030-interface.html). Through Interfaces, Astarte creates and maintains a data model autonomously, sparing the user from the complexity of dealing with Databases and Data Management in general.

## AMQP as internal API mechanism

Astarte services use a Protobuf-based API to exchange data over AMQP in a [gRPC](https://grpc.io/) like fashion. As such, as long as a service conforms with the policies defined by the queues, it is possible to extend Astarte in virtually any language that can deliver a compliant AMQP client.

## Device ID

Astarte identifies each device with a 128 bit Device ID which has to be unique within its Realm. As a best practice, it is advised to generate such an ID from hardware unique IDs or using dedicated hardware modules, to make it consistent across device reflashes. It is advised to use a cryptographic hash function (such as sha256) when generating it using a software module. Astarte will use URL encoded base64 (without padding) strings like `V_zv6ThCCtXWveQ8mPjsKg` in its representation.

This detail is relevant not only for identifying and querying the device, but also for the [Pairing mechanism](050-pairing_mechanism.html), as a device's credentials are associated to its Device ID.

*Note: currently, Astarte accepts Device IDs longer than 128 bit, which are then truncated to 128 bit internally. This behaviour exists for compatibility reasons but it's not supported and will likely change in future releases - hence, refrain from using anything which is not a 128-bit Device ID.*

*Note: As much as Device IDs should effectively be unique per-realm and this configuration will always be supported, some future optional optimizations might be available on top of the assumption that Device IDs are globally unique to an Astarte installation. Given the Device ID format has a 2<sup>-128</sup> chance of collision, it is safe to assume that as long as best practices for Device ID generation are followed, Device IDs will always be globally unique.*

## Device interaction

Astarte assumes devices are capable of exchanging data over a transport/protocol supporting SSL/TLS (e.g.: MQTT). This is a strong requirement, as Astarte identifies devices through client SSL certificates when it comes to data exchange.

Each transport implementation must be capable of mapping interfaces and out-of-band messages on top of it. Astarte itself does not care about the implementation detail of the transport itself, as the transport is in charge of converting its input to an AMQP message following Astarte's internal API specification.

Astarte's official reference and recommended design is MQTT using [VerneMQ](http://vernemq.com/) and its Astarte plugin.

### Device SDK and code generation

Device SDKs can take advantage of the interface design to dynamically generate code for exchanging data with Astarte. This way, developers using Device SDKs are spared from knowing details about the underlying transports and protocols, and can use a data-driven API.

However, there are some limitations and requirements:

 * The SDK requires SSL support - Astarte does not allow exchanging data over unencrypted channels and its design builds on the assumption that everything runs on top of SSL. If your device isn't capable of SSL, you are probably looking for Gateway support in Astarte.
 * As much as the SDK can implement virtually any transport protocol, it is required that the SDK supports at least HTTP(s) for Pairing.

## Realms and multitenancy

Astarte is natively multitenant through the concept of Realms. Each Realm is a logical portion of Astarte, and usually represents an organization or, in general, a set of devices physically/logically isolated.

Realms build upon the concept of keyspaces in Cassandra. Each Realm has its very own keyspace and has no shared data with other Realms. In fact, it is even possible to have a dedicated Cassandra cluster for a single realm in complex installations.

## Message Ordering

In Astarte, transports are given the task to deliver messages in a well-known AMQP structure. The ordering of such messages is then preserved on a set of criterias:

* There is no such thing as "in-order" among devices. A message X sent to device A can be processed after a message Y sent to device B even if Y was ingested in the AMQP queue before X. This is intentional and by design.
* All messages to a specific device A are *always guaranteed* to be processed in the very same order of the transport ingestion.
* Ordering is not dependent on the message timestamp, which can be set by different sources (depending on the interface's definition of timestamp). For example, interface A has explicit timestamping while interface B doesn't. Message X from A has an earlier timestamp than message Y from B, but if message Y has been ingested before X, Y will be processed before X regardless.
* Responsibility of message ordering *before* entering AMQP is entirely up to the transport, and different transports might have different behaviors when it comes to message ordering. Astarte provides this guarantee right after the transport itself.
* Message ordering concerns only pipelines in the [DUP](020-components.html#data-updater-plant-dup), including but not limited to data ingestion in the Database and Simple Triggers.

## Triggers

Triggers are rules which are "triggered" whenever one or more conditions are satisfied. Every satisfied condition generates an ordered event for the [Trigger Engine](020-components.html#trigger-engine) to be processed. They are one of the core concepts in Astarte and are the preferred way to handle push interactions between Astarte and connected applications.

More details about triggers can be found in the [dedicated section](060-triggers.html).


