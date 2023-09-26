# Interface Schema

The schema contains the following objects:

* [`Interface`](#reference-astarte-interface-schema) (root object)
* [`Mapping`](#reference-astarte-mapping-schema)


---------------------------------------
<a name="reference-astarte-interface-schema"></a>
## Interface

This schema describes how an Astarte interface should be declared

**Properties**

|   |Type|Description|Required|
|---|----|-----------|--------|
|**interface_name**|`string`|The name of the interface. This has to be an unique, alphanumeric reverse internet domain name, shorther than 128 characters.| ✔ Yes|
|**version_major**|`integer`|A Major version qualifier for this interface. Interfaces with the same id and different version_major number are deemed incompatible. It is then acceptable to redefine any property of the interface when changing the major version number.| ✔ Yes|
|**version_minor**|`integer`|A Minor version qualifier for this interface. Interfaces with the same id and major version number and different version_minor number are deemed compatible between each other. When changing the minor number, it is then only possible to insert further mappings. Any other modification might lead to incompatibilities and undefined behavior.| ✔ Yes|
|**type**|`string`|Identifies the type of this Interface. Currently two types are supported: datastream and properties. datastream should be used when dealing with streams of non-persistent data, where a single path receives updates and there's no concept of state. properties, instead, are meant to be an actual state and as such they have only a change history, and are retained.| ✔ Yes|
|**ownership**|`string`|Identifies the quality of the interface. Interfaces are meant to be unidirectional, and this property defines who's sending or receiving data. device means the device/gateway is sending data to Astarte, consumer means the device/gateway is receiving data from Astarte. Bidirectional mode is not supported, you should instantiate another interface for that.| ✔ Yes|
|**aggregation**|`string`|Identifies the aggregation of the mappings of the interface. Individual means every mapping changes state or streams data independently, whereas an object aggregation treats the interface as an object, making all the mappings changes interdependent. Choosing the right aggregation might drastically improve performances.|No, default: `"individual"`|
|**description**|`string`|An optional description of the interface.|No|
|**doc**|`string`|A string containing documentation that will be injected in the generated client code.|No|
|**mappings**|[`Astarte Mapping Schema`](#reference-astarte-mapping-schema) `[1-1024]`|Mappings define the endpoint of the interface, where actual data is stored/streamed. They are defined as relative URLs (e.g. /my/path) and can be parametrized (e.g.: /%{myparam}/path). A valid interface must have no mappings clash, which means that every mapping must resolve to a unique path or collection of paths (including parametrization). Every mapping acquires type, quality and aggregation of the interface.| ✔ Yes|

Additional properties are allowed.

### astarte.interface.schema.interface_name ✔

The name of the interface. This has to be an unique, alphanumeric reverse internet domain name,
shorther than 128 characters.

* **Type**: `string`
* **Required**: Yes
* **Minimum Length**`: >= 1`

### astarte.interface.schema.version_major ✔

A Major version qualifier for this interface. Interfaces with the same id and different
version_major number are deemed incompatible. It is then acceptable to redefine any property of the
interface when changing the major version number.

* **Type**: `integer`
* **Required**: Yes

### astarte.interface.schema.version_minor ✔

A Minor version qualifier for this interface. Interfaces with the same id and major version number
and different version_minor number are deemed compatible between each other. When changing the minor
number, it is then only possible to insert further mappings. Any other modification might lead to
incompatibilities and undefined behavior.

* **Type**: `integer`
* **Required**: Yes

### astarte.interface.schema.type ✔

Identifies the type of this Interface. Currently two types are supported: datastream and properties.
datastream should be used when dealing with streams of non-persistent data, where a single path
receives updates and there's no concept of state. properties, instead, are meant to be an actual
state and as such they have only a change history, and are retained.

* **Type**: `string`
* **Required**: Yes
* **Allowed values**:
   * `"datastream"`
   * `"properties"`

### astarte.interface.schema.ownership ✔

Identifies the quality of the interface. Interfaces are meant to be unidirectional, and this
property defines who's sending or receiving data. device means the device/gateway is sending data to
Astarte, consumer means the device/gateway is receiving data from Astarte. Bidirectional mode is not
supported, you should instantiate another interface for that.

* **Type**: `string`
* **Required**: Yes
* **Allowed values**:
   * `"device"`
   * `"server"`

### astarte.interface.schema.aggregation

Identifies the aggregation of the mappings of the interface. Individual means every mapping changes
state or streams data independently, whereas an object aggregation treats the interface as an
object, making all the mappings changes interdependent. Choosing the right aggregation might
drastically improve performances.

* **Type**: `string`
* **Required**: No, default: `"individual"`
* **Allowed values**:
   * `"individual"`
   * `"object"`

### astarte.interface.schema.description

An optional description of the interface.

* **Type**: `string`
* **Required**: No

### astarte.interface.schema.doc

A string containing documentation that will be injected in the generated client code.

* **Type**: `string`
* **Required**: No

### astarte.interface.schema.mappings ✔

Mappings define the endpoint of the interface, where actual data is stored/streamed. They are
defined as relative URLs (e.g. /my/path) and can be parametrized (e.g.: /%{myparam}/path). A valid
interface must have no mappings clash, which means that every mapping must resolve to a unique path
or collection of paths (including parametrization). Every mapping acquires type, quality and
aggregation of the interface.

* **Type**: [`Astarte Mapping Schema`](#reference-astarte-mapping-schema) `[1-1024]`
   * Each element in the array must be unique.
* **Required**: Yes




---------------------------------------
<a name="reference-astarte-mapping-schema"></a>
## Mapping

Identifies a mapping for an interface. A mapping must consist at least of an endpoint and a type.

**Properties**

|   |Type|Description|Required|
|---|----|-----------|--------|
|**endpoint**|`string`|The template of the path. This is a UNIX-like path (e.g. /my/path) and can be parametrized. Parameters are in the %{name} form, and can be used to create interfaces which represent dictionaries of mappings. When the interface aggregation is object, an object is composed by all the mappings for one specific parameter combination.| ✔ Yes|
|**type**|`string`|Defines the type of the mapping.| ✔ Yes|
|**reliability**|`string`|Useful only with datastream. Defines whether the sent data should be considered delivered when the transport successfully sends the data (unreliable), when we know that the data has been received at least once (guaranteed) or when we know that the data has been received exactly once (unique). unreliable by default. When using reliable data, consider you might incur in additional resource usage on both the transport and the device's end.|No, default: `"unreliable"`|
|**explicit_timestamp**|`boolean`|Allow to set a custom timestamp, otherwise a timestamp is added when the message is received. If true explicit timestamp will also be used for sorting. This feature is only supported on datastreams.|No, default: `false`|
|**retention**|`string`|Useful only with datastream. Defines whether the sent data should be discarded if the transport is temporarily uncapable of delivering it (discard) or should be kept in a cache in memory (volatile) or on disk (stored), and guaranteed to be delivered in the timeframe defined by the expiry. discard by default.|No, default: `"discard"`|
|**expiry**|`integer`|Useful when retention is stored. Defines after how many seconds a specific data entry should be kept before giving up and erasing it from the persistent cache. A value <= 0 means the persistent cache never expires, and is the default.|No, default: `0`|
|**database_retention_policy**|`string`|Useful only with datastream. Defines whether data should expire from the database after a given interval. Valid values are: no_ttl and use_ttl.|No, default: `"no_ttl"`|
|**database_retention_ttl**|`integer`|Useful when database_retention_policy is `"use_ttl"`. Defines how many seconds a specific data entry should be kept before erasing it from the database.|No|
|**allow_unset**|`boolean`|Used only with properties. Used with producers, it generates a method to unset the property. Used with consumers, it generates code to call an unset method when an empty payload is received.|No, default: `false`|
|**description**|`string`|An optional description of the mapping.|No|
|**doc**|`string`|A string containing documentation that will be injected in the generated client code.|No|

Additional properties are allowed.

### astarte.mapping.schema.endpoint ✔

The template of the path. This is a UNIX-like path (e.g. /my/path) and can be parametrized.
Parameters are in the %{name} form, and can be used to create interfaces which represent
dictionaries of mappings. When the interface aggregation is object, an object is composed by all the
mappings for one specific parameter combination.

* **Type**: `string`
* **Required**: Yes
* **Minimum Length**`: >= 2`

### astarte.mapping.schema.type ✔

Defines the type of the mapping.

* **Type**: `string`
* **Required**: Yes
* **Allowed values**:
   * `"double"`
   * `"integer"`
   * `"boolean"`
   * `"longinteger"`
   * `"string"`
   * `"binaryblob"`
   * `"datetime"`
   * `"doublearray"`
   * `"integerarray"`
   * `"booleanarray"`
   * `"longintegerarray"`
   * `"stringarray"`
   * `"binaryblobarray"`
   * `"datetimearray"`

### astarte.mapping.schema.reliability

Useful only with datastream. Defines whether the sent data should be considered delivered when the
transport successfully sends the data (unreliable), when we know that the data has been received at
least once (guaranteed) or when we know that the data has been received exactly once (unique).
unreliable by default. When using reliable data, consider you might incur in additional resource
usage on both the transport and the device's end.

* **Type**: `string`
* **Required**: No, default: `"unreliable"`
* **Allowed values**:
   * `"unreliable"`
   * `"guaranteed"`
   * `"unique"`

### astarte.mapping.schema.explicit_timestamp

Allow to set a custom timestamp, otherwise a timestamp is added when the message is received. If
true explicit timestamp will also be used for sorting. This feature is only supported on
datastreams.

* **Type**: `boolean`
* **Required**: No, default: `false`

### astarte.mapping.schema.retention

Useful only with datastream. Defines whether the sent data should be discarded if the transport is
temporarily uncapable of delivering it (discard) or should be kept in a cache in memory (volatile)
or on disk (stored), and guaranteed to be delivered in the timeframe defined by the expiry. discard
by default.

* **Type**: `string`
* **Required**: No, default: `"discard"`
* **Allowed values**:
   * `"discard"`
   * `"volatile"`
   * `"stored"`

### astarte.mapping.schema.expiry

Useful when retention is stored. Defines after how many seconds a specific data entry should be kept
before giving up and erasing it from the persistent cache. A value <= 0 means the persistent cache
never expires, and is the default.

* **Type**: `integer`
* **Required**: No, default: `0`

### astarte.mapping.schema.database_retention_policy
Useful only with datastream. Defines whether data is expired from the database after a given time to
live interval. When `"no_ttl"` is used data are not expired.

* **Type**: `string`
* **Required**: No

### astarte.mapping.schema.database_retention_ttl

Useful when database_retention_policy is `"use_ttl"`. Defines how many seconds a specific data entry
should be kept before erasing it from the database.

* **Type**: `integer`
* **Required**: No

### astarte.mapping.schema.allow_unset

Used only with properties. Used with producers, it generates a method to unset the property. Used
with consumers, it generates code to call an unset method when an empty payload is received.

* **Type**: `boolean`
* **Required**: No, default: `false`

### astarte.mapping.schema.description

An optional description of the mapping.

* **Type**: `string`
* **Required**: No

### astarte.mapping.schema.doc

A string containing documentation that will be injected in the generated client code.

* **Type**: `string`
* **Required**: No
