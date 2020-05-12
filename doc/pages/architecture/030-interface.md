# Interfaces

Interfaces are a core concept of Astarte which defines how data is exchanged between Astarte and its
peers. They are not to be intended as OOP interfaces, but rather as the following definition:

> In computing, an interface is a shared boundary across which two or more separate components of a
> computer system exchange information.

In Astarte each interface has an owner, can represent either a continuous data stream or a snapshot
of a set of properties, and can be either aggregated into an object or be an independent set of
individual members.

If you are already familiar with interface's basic concepts, you might want to jump directly to the
[Interface Schema](040-interface_schema.html).

## Versioning

Interfaces are versioned, each interface having both a major version and a minor
version number. The concept behind these two version numbers mimics [Semantic
Versioning](http://semver.org/): arbitrary changes can happen exclusively between different major
versions (e.g. removing members, changing types, etc...), whereas minor versions allow incremental
additive changes only (e.g. adding members).

Several different major versions of the same interface can coexist at the same time in Astarte,
although a Device can hold only a single version of an interface at a time (even though interfaces
can be updated over time). Interfaces, internally, are univocally identified by their name and their
major version.

## Format

Interfaces are described using a JSON document. Each interface is identified by an unique
interface name of maximum 128 characters, which must be a [Reverse Domain
Name](https://en.wikipedia.org/wiki/Reverse_domain_name_notation). As a convention, the interface
name usually contains its author's URI Reverse Internet Domain Name.

An example skeleton looks like this:

```json
{
    "interface_name": "com.test.MyInterfaceName",
    "version_major": 1,
    "version_minor": 0,
    [...]
}
```

Valid values and variables are listed in the [Interface Schema](040-interface_schema.html).

### Name limitations

A valid interface name consists of a Reverse Domain Name containing alphanumeric characters, hyphens
and dots. By design, both the top level domain and last domain component can not contain hyphens,
although hypens are allowed in other parts of the interface name (e.g.: `org.astarte-platform.Values`
is a valid interface name).

Interface names have to be fully-defined Reverse Domain Names. `Values` will not be accepted as an
Astarte interface name, whereas `org.astarte-platform.Values` is a valid one.

Interface's uniqueness is case insensitive - this means you cannot install two interfaces with the
same name and different casing (e.g.: `org.astarte-platform.MyValues` and `org.astarte-platform.Myvalues`).
This also applies to Major versioning: interfaces sharing the same name with a different major
version cannot have different casing.

Although not enforced, naming conventions for Astarte Interfaces require lowercasing for anything but
the last part of the Interface name, which should be CamelCase.

Valid examples are:

* `org.astarte-platform.conventions.ValidInterfaceName`
* `org.astarte-platform.ValidInterfaceName`
* `org.astarte-platform.conventions.satisfied.ValidInterfaceName`

Non-valid examples are:

* `org.astarte-platform.Conventions.ValidInterfaceName`
* `org.astarte-platform.validInterfaceName`
* `org.astarte-platform.Conventions.satisfied.ValidInterfaceName`

## Interface Type

Interfaces have a well-known, predefined type, which can be either `property` or
`datastream`. Every Device in Astarte can have any number of interfaces of any different types.

### Datastream

`datastream` represents a mutable, ordered stream of data, with no concept of
persistent state or synchronization. As a rule of thumb, `datastream` interfaces should be used when
dealing with values such as sensor samples, commands and events. `datastream` are stored as time
series in the database, making them suitable for time span filtering and any other common time
series operation, and they are not idempotent in the REST API semantics.

Due to their nature, `datastream` interfaces have a number of [additional
properties](#datastream-specific features) which fine tune their behavior.

### Properties

`properties` represent a persistent, stateful, synchronized state with no concept of
history or timestamping. `properties` are useful, for example, when dealing with settings, states or
policies/rules. `properties` are stored in a key-value fashion, and grouped according to their
interface, and they are idempotent in the REST API semantics. Rather than being able to act on a
stream like in the `datastream` case, `properties` can be retrieved, or can be used as a
[trigger](060-triggers.html) whenever they change.

Values in a `properties` interface can be unset (or deleted according to the http jargon): to allow
such a thing, the interface must have its `allow_unset` property set to `true`. Please [refer to the
JSON Schema](040-interface_schema.html) for further details.

## Ownership

Astarte's design mandates that each interface has an owner. The owner of an interface
has a write-only access to it, whereas other actors have read-only access. Interface **ownership**
can be either `device` or `server`: the owner is the actor producing the data, whereas the other
actor consumes data.

## Mappings

Every interface must have an array of mappings. Mappings are designed around REST
controller semantics: each mapping describes an endpoint which is resolved to a path, it is strongly
typed, and can have additional options. Just like in REST controllers, Endpoints can be parametrized
to build REST-like collection and trees. Parameters are identified by `%{parameterName}`, with each
endpoint supporting any number of parameters (see [Limitations](#limitations)).

This is how a parametrized mapping looks like:

```json
    [...]
    "mappings": [
        {
            "endpoint": "/%{itemIndex}/value",
            "type": "integer",
            "reliability": "unique",
            "retention": "discard"
        },
    [...]
```

In this example, `/0/value`, `/1/value` or `/test/value` all map to a valid endpoint, while
`/te/st/value` can't be resolved by any endpoint.

### Supported data types

The following types are supported:

* `double`: A double-precision floating-point number as specified by binary64, by the IEEE 754
  standard (NaNs and other non numerical values are not supported).
* `integer`: A signed 32 bit integer.
* `boolean`: Either `true` or `false`, adhering to JSON boolean type.
* `longinteger`: A signed 64 bit integer (please note that `longinteger` is represented as a string
  by default in JSON-based APIs.).
* `string`: An UTF-8 string, at most 65536 bytes long.
* `binaryblob`: An arbitrary sequence of any byte that should be shorter than 64 KiB. (`binaryblob`
  is represented as a base64 string by default in JSON-based APIs.).
* `datetime`: A UTC timestamp, internally represented as milliseconds since 1st Jan 1970 using a
  signed 64 bits integer. (`datetime` is represented as an ISO 8601 string by default in JSON based
  APIs.)
* `doublearray`, `integerarray`, `booleanarray`, `longintegerarray`, `stringarray`,
  `binaryblobarray`, `datetimearray`: A list of values, represented as a JSON Array. Arrays can have
  up to 1024 items and each item must respect the limits of its scalar type (_i.e._ each string in a
  `stringarray` must be at most 65535 bytes long, each binary blob in a `binaryblobarray` must be
  shorter than 64 KiB.

Make sure that the differences between two distinct interface names are not limited to the casing or
the presence of hyphens. This situation leads to a collision in the interface names which brings to
an error in the interface installation process.

A valid interface must resolve a path univocally to a single endpoint. Take the following example:

```json
    [...]
    "mappings": [
        {
            "endpoint": "/%{itemIndex}/value",
            "type": "integer"
        },
        {
            "endpoint": "/myPath/value",
            "type": "integer"
        },
    [...]
```

In such a case, the interface isn't valid and is
rejected, due to the fact that path `/myPath/value` is ambiguous and could be resolved to two
different endpoints.

Any endpoint configuration must not generate paths that are prefix of other paths, for this reason
the following example is also invalid:

```json
    [...]
    "mappings": [
        {
            "endpoint": "/some/thing",
            "type":"integer"
        },
        {
            "endpoint": "/some/%{param}/value",
            "type": "integer"
        },
    [...]

```

In case the interface's aggregation is `object`, additional restrictions apply. Endpoints in the
same interface must all have the same depth, and the same number of parameters. If the interface is
parametrized, every endpoint must have the same parameter name at the same level. This is an example
of a valid aggregated interface mapping:

```json
    [...]
    "mappings": [
        {
            "endpoint": "/%{itemIndex}/value",
            "type": "integer"
        },
        {
            "endpoint": "/%{itemIndex}/otherValue",
            "type": "string"
        },
    [...]
```

## Aggregation

In a real world scenario, such as an array of sensors, there are usually two main
cases. A sensor might have one or more independent values which are sampled individually and sent
whenever they become available independently. Or a sensor might sample at the same time a number of
values, which might as well have some form of correlation.

In Astarte, this concept is mapped to interface `aggregation`. In case aggregation is `individual`,
each mapping is treated as an independent value and is managed individually. In case aggregation is
`object`, Astarte expects the owner to send all of the interface's mappings at the same time, packed
in a single message. In this case, all of the mappings share some core properties such as the
timestamp.

Aggregation is a powerful mechanism that can be used to map interfaces to real world *"objects"*.
Moreover, aggregated interfaces can also be parametrized, although with [some
limitations](#limitations).

### Endpoints and aggregation

Since Astarte 0.11, Aggregations cannot have endpoints with depth 1. This was an erroneously allowed
behavior in Astarte 0.10 which is kept for retrocompatibility - however, new interfaces should ensure
each endpoint in an aggreate has at least depth 2, as support for depth 1 will be removed in a future
release. This change has been done to be consistent with AppEngine API design, and to ensure that
path `/` is not ambiguous.

This is the correct way to set up a valid endpoint structure for an aggregate:

```json
    [...]
    "mappings": [
        {
            "endpoint": "/objects/value",
            "type": "integer"
        },
        {
            "endpoint": "/objects/otherValue",
            "type": "string"
        },
    [...]
```

The following structure, instead, is deprecated:

```json
    [...]
    "mappings": [
        {
            "endpoint": "/value",
            "type": "integer"
        },
        {
            "endpoint": "/otherValue",
            "type": "string"
        },
    [...]
```

## Datastream-specific features

`datastream` interfaces are highly tunable, depending on the kind of
data they are representing: it is possible to fine tune several aspects of how data is stored,
transferred and indexed. The following properties can be set either at interface level, making them
the default for each mapping, or at mapping level, overriding any interface-wide setting.

> NOTE: In case the interface is aggregated, overriding any additional properties at mapping level
> does not have any effect, and might cause a validation error.

* `explicit_timestamp`: By default, Astarte associates a timestamp to data whenever it is collected
  (or - when the message hits the data collection stage). However, when setting this property to
  `true`, Astarte expects the owner to attach a valid timestamp each time it produces data. In that
  case, the provided timestamp is used for indexing.
* `reliability`: Each mapping can be `unreliable` (default), `guaranteed`, `unique`. This defines
  whether data should be considered delivered when the transport successfully sends the data
  regardless of the outcome (`unreliable`), when data has been received at least once by the
  recipient (`guaranteed`) or when data has been received exactly once by the recipient (`unique`).
  When using `reliable` data, consider you might incur in additional resource usage on both the
  transport and the device's end.
* `retention`: Each mapping can have a `discard` (default), `volatile`, `stored` retention. This
  defines whether data should be discarded if the transport is temporarily uncapable of delivering
  it (`discard`), should be kept in a cache in memory (`volatile`) or on disk (`stored`), and
  guaranteed to be delivered in the timeframe defined by the `expiry`.
* `expiry`: Meaningful only when `retention` is `stored`. Defines how many seconds a specific data
  entry should be kept before giving up and erasing it from the persistent cache. A value <= 0 means
  the persistent cache never expires, and is the default.
* `database_retention_policy`: Useful only with datastream. Defines whether data should expire
   from the database after a given interval. Valid values are: no_ttl and use_ttl.
* `database_retention_ttl`: Useful when database_retention_policy is `"use_ttl"`. Defines how many
  seconds a specific data entry should be kept before erasing it from the database.

## Best practices

* When creating interface drafts, or for testing purposes in general, it is recommended to use 0 as
  the major version, to make maintenance and testing easier. Currently, Astarte allows only
  interfaces with `major_version` == 0 to be deleted, and this limitation will probably be never
  lifted to prevent data loss.
* When sending real time commands in `datastream` interfaces, `discard` is usually the best option.
  Even though it does not guarantee delivery, it prevents users from unwillingly sending the same
  command over and over if the recipient isn't available, causing a queue of commands to be sent to
  the recipient when it gets back online. In general, [`retention`](#datastream-specific-features)
  should be used to keep track of low traffic/important events
