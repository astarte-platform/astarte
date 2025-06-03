# Triggers

Triggers in Astarte are the go-to mechanism for generating push events. In contrast with AppEngine's
REST APIs, Triggers allow users to specify conditions upon which a custom payload is delivered to a
recipient, using a specific `action`, which usually maps to a specific transport/protocol, such as
HTTP.

Given this kind of flexibility, triggers are the most powerful way to push data to an external
service, potentially without any additional customization.

Triggers can be managed from [Realm Management
API](api/index.html?urls.primaryName=Realm%20Management%20API#/trigger), `astartectl` with the
`astartectl realm-management triggers` subcommand, or Astarte Dashboard in the `Triggers` page.

## Building Triggers

Triggers can be either built manually or using Astarte Dashboard's Trigger Editor. Trigger Editor
dynamically loads installed Interfaces in the Realm and eases trigger creation by providing not
only linting and validation, but also dynamic resolution of Interface names.

Trigger Editor works in a very similar fashion to Interfaces Editor, and shares the same User
Interface.

### Format

A trigger is described using a JSON document. Each trigger is defined by two main parts: `condition`
and `action`.

This is a JSON representation of an example trigger:

```json
{
  "name": "example_trigger",
  "action": {
    "http_url": "https://example.com/my_hook",
    "http_method": "post"
  },
  "simple_triggers": [
    {
      "type": "data_trigger",
      "on": "incoming_data",
      "interface_name": "org.astarte-platform.genericsensors.Values",
      "interface_major": 0,
      "match_path": "/streamTest/value",
      "value_match_operator": ">",
      "known_value": 0.4
    }
  ]
}
```

The `condition` is represented by the `simple_triggers` array. In this release, Astarte supports
only a single entry in the `simple_triggers` array, but support for multiple simple triggers (and
different ways to combine them) is planned for future releases.

The `condition` in the example specifies that when data is received on the
`org.astarte-platform.genericsensors.Values` interface on `/streamTest/value` path, if the value of said data is `> 0.4`,
then the trigger is activated. For more information about all the possible conditions, check out the
[Conditions section](#conditions)

The `action` object describes what the result of the trigger will be. In this specific case, an HTTP
`POST` request will be sent to `https://example.com/my_hook`, with the payload:

```json
{
  "timestamp": "<event_timestamp>",
  "device_id": "<device_id>",
  "event": {
    "type": "incoming_data",
    "interface": "org.astarte-platform.genericsensors.Values",
    "path": "/streamTest/value",
    "value": <some_value>
  }
}
```

To know more about all possible actions, check the [Actions section](#actions)

## Conditions

A condition defines the event upon which an action is triggered. Conditions are expressed through
simple triggers. Astarte monitors incoming events and triggers a corresponding action whenever there
is a match.

Simple triggers are divided into two types: [Device Triggers](#device-triggers) and [Data
Triggers](#data-triggers).

### Device Triggers

Device triggers express conditions matching the state of a device.

This is the generic representation of a Device Trigger:

```json
{
  "type": "device_trigger",
  "on": "<device_trigger_type>",
  "device_id": "<device_id>",
  "group_name": "<group_name>"
}
```

#### Parameters

`device_trigger_type` can be one of the following:

- `device_connected`: triggered when a device connects to its transport.
- `device_disconnected`: triggered when a device disconnects from its transport.
- `device_error`: triggered when data from a device causes an error.

`device_id` can be used to pass a specific Device ID to restrict the trigger to a single device. `*`
is also accepted as `device_id` to maintain backwards compatibility and it is considered equivalent
to no `device_id` specified.

`group_name` can be used to restrict the trigger to all devices that are member of the group.

`device_id` and `group_name` are mutually exclusive and if neither of them is specified in the
simple trigger, the simple trigger will be installed for all devices in a realm.

### Data Triggers

Data triggers express conditions matching data coming from a device.

This is the generic representation of a Data Trigger:

```json
{
  "type": "data_trigger",
  "device_id": "<device_id>",
  "group_name": "<group_name>",
  "on": "<data_trigger_type>",
  "interface_name": "<interface_name>",
  "interface_major": "<interface_major>",
  "match_path": "<match_path>",
  "value_match_operator": "<value_match_operator>",
  "known_value": <known_value>
}
```

Data triggers are installed for all devices in a Realm.

#### Data Triggers Parameters

`device_id` can be used to pass a specific Device ID to restrict the trigger to a single device. `*`
is also accepted as `device_id` to maintain backwards compatibility and it is considered equivalent
to no `device_id` specified.

`group_name` can be used to restrict the trigger to all devices that are member of the group.

`device_id` and `group_name` are mutually exclusive and if neither of them is specified in the
simple trigger, the simple trigger will be installed for all devices in a realm.

`data_trigger_type` can be one of the following:

- `incoming_data`: verifies the condition whenever new data arrives.
- `value_stored`: verifies the condition whenever new data arrives, after it is saved to the
  database.
- `value_change`: works only with properties interface; verifies the condition whenever the
  received value is different from the previous one.
- `value_change_applied`: works only with properties interface; verifies the condition whenever the
  last value received is different from the last one previously received, after it is saved to the
  database.
- `path_created`: verifies the condition whenever a new path in a property interface is set or the
  first value is streamed on a datastream interface.
- `path_removed`: works only with properties interface; verifies the condition whenever a property
  path is unset.

`interface_name` and `interface_major` represent, respectively, the Interface name and major version
that uniquely identify an Astarte Interface. `interface_name` can be `*` to match all interfaces; in
that case `interface_major` is ignored and all major numbers are matched.

`match_path` is the path that will be used to match the condition. It can be `/*` to match all the
paths of an interface.

`value_match_operator` is the operator used to match the incoming data against a known value. It can
be `*` to indicate that all values should be matched (`known_value` is ignored in that case),
otherwise it can be one of these operators: `==`, `!=`, `>`, `>=`, `<`, `<=`, `contains`,
`not_contains`. The match is always performed with `<incoming_value> <operator> <known_value>`.
`contains` and `not_contains` can be used only with type `string`, `binaryblob` and with array types.

`known_value` is the value used with `value_match_operator` to perform the comparison on the
incoming value. It must have the same type as the incoming value, except in the `contains` and
`not_contains` case.

## Actions

Actions are triggered by a matching condition. An Action defines how the event should be sent to the
outer world (e.g. an http POST on a certain URL). In addition, most actions have a Payload, which
carries the body of the event.

### HTTP Actions

Payloads are most of the time represented as text, and Astarte provides several ways to generate
them. By default Astarte generates a JSON payload with all the relevant information of the event.
This is also the format used when delivering payloads in Astarte Channels. The format of the payload
can be found in the [Default action](#default-action) section.

Astarte also provides a powerful templating mechanism for plain-text payloads based on top of
[Mustache](https://mustache.github.io/). This is especially useful for integrating with third-party
actors which require custom plain-text payloads. Keep in mind that Mustache templates are only able
to produce `text/plain` payloads, not valid JSON.

#### Default action

This is the configuration object representing a minimal default action:

```json
{
  "http_url": "<http_url>",
  "http_method": "<method>"
}
```

The default action sends an HTTP request to the specified `http_url` using `http_method` method (e.g. `POST`).

Further options might be used, such as "http_static_headers", enabling auth to remote services:

```json
{
  "http_url": "<http_url>",
  "http_method": "<method>",
  "http_static_headers": {
    "Authorization": "Bearer <token>"
  },
  "ignore_ssl_errors": <true|false>
}
```

The `ignore_ssl_errors` key is optional and defaults to `false`. If set to `true`, any SSL error
encountered while doing the HTTP request will be ignored. This can be useful if the trigger must
ignore self-signed or expired certificates.

Please, beware that some http headers might be not allowed or reserved for http connection signaling.

### SimpleEvent payloads

The payload delivered in a default HTTP action or in [Astarte Channels](052-using_channels.html) is
a JSON document with this format:

```json
{
  "timestamp": "<timestamp>",
  "device_id": "<device_id>",
  "trigger_name": "<trigger_name>",
  "event": <event>
}
```

`timestamp` is an UTC [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) timestamp (e.g.
`"2019-10-16T08:56:08.534377Z"`) representing when the event happened.

`device_id` identifies the device that triggered the event.

`trigger_name` identifies the trigger that fired the event.

`event` is a JSON object that has a specific structure depending on the type of the `simple_trigger`
that generated it. Event objects are detailed below.

Additionally, the realm that originated the trigger is available in the request in the
`Astarte-Realm` header.

##### Event objects

###### DeviceConnectedEvent

```json
{
  "type": "device_connected",
  "device_ip_address": "<device_ip_address>"
}
```

`device_ip_address` is the IP address of the device.

###### DeviceDisconnectedEvent

```json
{
  "type": "device_disconnected"
}
```

###### DeviceErrorEvent

```json
{
  "type": "device_error",
  "error_name": "<error_name>",
  "metadata": {
    "<key>": "<value>"
  }
}
```

`error_name` is a string identifying the error. More details can be found in the [device errors
documentation](045-device_errors.html)

`metadata` is a map with string key and string values that may contain additional information about
the error. Some metadata (_e.g._ binary payloads) might be encoded in base64 if they cannot be
represented as string. In that case, the key is prepended with the `base64_` prefix.

###### IncomingDataEvent

```json
{
  "type": "incoming_data",
  "interface": "<interface>",
  "path": "<path>",
  "value": <value>
}
```

`interface` is the interface on which data was received.

`path` is the path on which data was received.

`value` is the received value. Its type depends on the type of the mapping it's coming from.
`binaryblob` and `binaryblobarray` type values are encoded with Base64.

###### ValueStoredEvent

```json
{
  "type": "value_stored",
  "interface": "<interface>",
  "path": "<path>",
  "value": <value>
}
```

`interface` is the interface on which data was received.

`path` is the path on which data was received.

`value` is the received value. Its type depends on the type of the mapping it's coming from.
`binaryblob` and `binaryblobarray` type values are encoded with Base64.

###### ValueChangeEvent

```json
{
  "type": "value_change",
  "interface": "<interface>",
  "path": "<path>",
  "old_value": <old_value>,
  "new_value": <new_value>
}
```

`interface` is the interface on which data was received.

`path` is the path on which data was received.

`old_value` is the previous value. Its type depends on the type of the mapping it's coming from.
`binaryblob` and `binaryblobarray` type values are encoded with Base64.

`new_value` is the received value. Its type depends on the type of the mapping it's coming from.
`binaryblob` and `binaryblobarray` type values are encoded with Base64.

###### ValueChangeAppliedEvent

```json
{
  "type": "value_change_applied",
  "interface": "<interface>",
  "path": "<path>",
  "old_value": <old_value>,
  "new_value": <new_value>
}
```

`interface` is the interface on which data was received.

`path` is the path on which data was received.

`old_value` is the previous value. Its type depends on the type of the mapping it's coming from.
`binaryblob` and `binaryblobarray` type values are encoded with Base64.

`new_value` is the received value. Its type depends on the type of the mapping it's coming from.
`binaryblob` and `binaryblobarray` type values are encoded with Base64.

###### PathCreatedEvent

```json
{
  "type": "path_created",
  "interface": "<interface>",
  "path": "<path>",
  "value": <value>
}
```

`interface` is the interface on which data was received.

`path` is the path that has been created.

`value` is the received value. Its type depends on the type of the mapping it's coming from.
`binaryblob` and `binaryblobarray` type values are encoded with Base64.

###### PathRemovedEvent

```json
{
  "type": "path_removed",
  "interface": "<interface>",
  "path": "<path>"
}
```

`interface` is the interface on which data was received.

`path` is the path that has been removed.

#### Mustache action

This is the configuration object representing a Mustache action:

```json
{
  "http_url": "<http_url>",
  "http_method": "<http_method>",
  "template_type": "mustache",
  "template": "<template>"
  "ignore_ssl_errors": <true|false>
}
```

The Mustache action sends an HTTP request to the specified `http_url`, with the payload
built with the [Mustache](https://mustache.github.io/) template specified in `template`. If the
template contains a key inside a double curly bracket (like so: `{{ key }}`), it will be substituted
with the actual value of that key in the event.

The basic keys that can be use to populate the template are:

- `{{ realm }}`: the realm the trigger belongs to.
- `{{ device_id }}`: the device that originated the trigger.
- `{{ trigger_name }}`: the trigger name.
- `{{ event_type }}`: the type of the received event.

The `ignore_ssl_errors` key is optional and defaults to `false`. If set to `true`, any SSL error
encountered while doing the HTTP request will be ignored. This can be useful if the trigger must
ignore self-signed or expired certificates.

Moreover, depending on the event type, all keys that are contained in the events [described in the
previous section](#event-objects) are available, always by wrapping them in `{{ }}`.

The realm is also sent in the `Astarte-Realm` header.

##### Example

This is an example of a trigger that uses Mustache action.

```json
{
  "name": "example_mustache_trigger",
  "action": {
    "template_type": "mustache",
    "template": "Device {{ device_id }} just connected from IP {{ device_ip_address }}",
    "http_url": "https://example.com/my_mustache_hook",
    "http_method": "post"
  },
  "simple_triggers": [
    {
      "type": "device_trigger",
      "on": "device_connected",
      "device_id": "*"
    }
  ]
}
```

When a device is connected, the following request will be received by
`https://example.com/my_mustache_hook`:

```http
POST /my_mustache_hook HTTP/1.1
Astarte-Realm: test
Content-Length: 63
Content-Type: text/plain
Host: example.com
User-Agent: hackney/1.13.0

Device ydqBlFsGQ--xZ-_efQxuLw just connected from IP 172.18.0.1
```

### Trigger Delivery Policies
When an [HTTP action](060-triggers.html#http-actions) is triggered, an event is sent to a specific URL.
However, it is possible that the request is not successfully completed, e.g. the required resource is momentarily not available.
[Trigger Delivery Policies](062-trigger_delivery_policies.html) specify what to do in case of delivery errors and
how to handle events which have not been successfully delivered.
A Trigger can be linked to one (at most) Trigger Delivery Policy by specifying the name of the policy in the `"policy"` field.
If no Trigger Delivery Policies are specified, Astarte will resort to the default (pre v1.1) behaviour, i.e. ignoring delivery errors.
Refer to the [relevant documentation](062-trigger_delivery_policies.html) for more information on Trigger Delivery Policies.

### AMQP 0-9-1 Actions

AMQP 0-9-1 actions might be configured as an alternative to HTTP actions for advanced use cases.
AMQP 0-9-1 is the right choice for a number of scenarios, including
[Astarte Flow](https://docs.astarte-platform.org/flow/snapshot) integration, high performance
ingestion, integration with an existing AMQP infrastructure, etc...

Payloads are always encoded using [protobuf](https://developers.google.com/protocol-buffers),
therefore if any other format is required Astarte Flow should be employed as a format converter.

This is a minimal configuration object representing an
[AMQP 0-9-1](https://www.rabbitmq.com/tutorials/amqp-concepts.html) action:

```json
{
  "amqp_exchange": "astarte_events_<realm-name>_<exchange-suffix>",
  "amqp_routing_key": "my_routing_key",
  "amqp_message_expiration_ms": <expiration in milliseconds>,
  "amqp_message_persistent": <true when disk persistency is used>
}
```

It is possible to configure more advanced AMQP 0-9-1 actions:

```json
{
  "amqp_exchange": "astarte_events_myrealm_myexchange",
  "amqp_routing_key": "my routing key",
  "amqp_static_headers": {
    "key": "value"
  },
  "amqp_message_expiration_ms": 10000,
  "amqp_message_priority": 0,
  "amqp_message_persistent": true,
}
```

Some Astarte specific restrictions apply:
* `amqp_exchange` must have `astarte_events_<realm-name>_<any-allowed-string>` format.
* `amqp_routing_key` must not contain `{` and `}`, which are reserved for future uses.

For further details [RabbitMQ documentation](https://www.rabbitmq.com/amqp-0-9-1-reference.html) is suggested.

## Relationship with Channels

Channels are part of AppEngine, and allow users to monitor device events through WebSockets, on top
of [Phoenix Channels](https://hexdocs.pm/phoenix/channels.html). Under the hood, Channels use
transient triggers to define which kind of events will flow through a specific room.
