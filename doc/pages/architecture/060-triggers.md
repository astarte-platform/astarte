# Triggers

Triggers in Astarte are the go-to mechanism for generating push events. In contrast with AppEngine's
REST APIs, Triggers allow users to specify conditions upon which a custom payload is delivered to a
recipient, using a specific `action`, which usually maps to a specific transport/protocol, such as
HTTP.

Given this kind of flexibility, triggers are the most powerful way to push data to an external
service, potentially without any additional customization.

Triggers can be managed from [Realm Management
API](api/index.html?urls.primaryName=Realm%20Management%20API#/trigger).

## Format

A trigger is described using a JSON document. Each trigger is defined by two main parts: `condition`
and `action`.

This is a JSON representation of an example trigger:
``` json
{
  "name": "example_trigger",
  "action": {
    "http_post_url": "https://example.com/my_hook"
  },
  "simple_triggers": [
    {
      "type": "data_trigger",
      "on": "incoming_data",
      "interface_name": "org.astarteplatform.Values",
      "interface_major": 0,
      "match_path": "/realValue",
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
`org.astarteplatform.Values` interface on `/realValue` path, if the value of said data is `> 0.4`,
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
    "interface": "org.astarteplatform.Values",
    "path": "/realValue",
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

This is the generic representation of a Data Trigger:

```json
{
  "type": "device_trigger",
  "on": "<device_trigger_type>",
  "device_id": "<device_id>"
}
```

#### Parameters

`device_trigger_type` can be one of the following:
- `device_connected`: triggered when a device connects to its transport.
- `device_disconnected`: triggered when a device disconnects from its transport.

`device_id` can be a specific Device ID or `*`, meaning the trigger will be installed for all
devices in a Realm.

### Data Triggers

Data triggers express conditions matching data coming from a device.

This is the generic representation of a Device Trigger:

```json
{
  "type": "data_trigger",
  "on": "<data_trigger_type>",
  "interface_name": "<interface_name>",
  "interface_major": "<interface_major>",
  "match_path": "<match_path>",
  "value_match_operator": "<value_match_operator>",
  "known_value": <known_value>
}
```

Data triggers are installed for all devices in a Realm.

#### Parameters

`data_trigger_type` can be one of the following:
- `incoming_data`: verifies the condition whenever new data arrives.
- `value_stored`: verifies the condition whenever new data arrives, after it is saved to the
  database.
- `value_change`: verifies the condition whenever the last value received is different from the
  last one previously received.
- `value_change_applied`: verifies the condition whenever the last value received is different from
  the last one previously received, after it is saved to the database.
- `path_created`: verifies the condition whenever a new path in a property interface is set or the
  first value is streamed on a datastream interface.
- `path_removed`: verifies the condition whenever a property path is unset.

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

Payloads are most of the time represented as text, and Astarte provides several ways to generate
them. By default Astarte generates a JSON payload with all the relevant information of the event.
This is also the format used when delivering payloads in Astarte Channels. The format of the payload
can be found in the [Default action](#default-action) section.

Astarte also provides a powerful templating mechanism for plain-text payloads based on top of
[Mustache](https://mustache.github.io/). This is especially useful for integrating with third-party
actors which require custom plain-text payloads. Keep in mind that Mustache templates are only able
to produce `text/plain` payloads, not valid JSON.

### Default action

This is the configuration object representing the default action:
```json
{
  "http_post_url": "<http_post_url>"
}
```

The default action sends an HTTP `POST` request to the specified `http_post_url`.

The payload of the request is JSON document with this format:
```json
{
  "timestamp": "<timestamp>",
  "device_id": "<device_id>",
  "event": <event>
}
```

`timestamp` is an UTC [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) timestamp (e.g.
`"2019-10-16T08:56:08.534377Z"`) representing when the event happened.

`device_id` identifies the device that triggered the event.

`event` is a JSON object that has a specific structure depending on the type of the `simple_trigger`
that generated it. Event objects are detailed below.

Additionally, the realm that originated the trigger is available in the request in the
`Astarte-Realm` header.

#### Event objects

- `DeviceConnectedEvent`
```json
{
  "type": "device_connected",
  "device_ip_address": "<device_ip_address>"
}
```

`device_ip_address` is the IP address of the device.

- `DeviceDisconnectedEvent`
```json
{
  "type": "device_disconnected"
}
```

- `IncomingDataEvent`
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

- `ValueStoredEvent`
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

- `ValueChangeEvent`
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

- `ValueChangeAppliedEvent`
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

- `PathCreatedEvent`
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

- `PathRemovedEvent`
```json
{
  "type": "path_removed",
  "interface": "<interface>",
  "path": "<path>"
}
```

`interface` is the interface on which data was received.

`path` is the path that has been removed.

### Mustache action

This is the configuration object representing a Mustache action:
```json
{
  "http_post_url": "<http_post_url>",
  "template_type": "mustache",
  "template": "<template>"
}
```

The Mustache action sends an HTTP `POST` request to the specified `http_post_url`, with the payload
built with the [Mustache](https://mustache.github.io/) template specified in `template`. If the
template contains a key inside a double curly bracket (like so: `{{ key }}`), it will be substituted
with the actual value of that key in the event.

The basic keys that can be use to populate the template are:
- `{{ realm }}`: the realm the trigger belongs to.
- `{{ device_id }}`: the device that originated the trigger.
- `{{ event_type }}`: the type of the received event.

Moreover, depending on the event type, all keys that are contained in the events [described in the
previous section](#event-objects) are available, always by wrapping them in `{{ }}`.

The realm is also sent in the `Astarte-Realm` header.

#### Example

This is an example of a trigger that uses Mustache action.
```json
{
  "name": "example_mustache_trigger",
  "action": {
    "template_type": "mustache",
    "template": "Device {{ device_id }} just connected from IP {{ device_ip_address }}",
    "http_post_url": "https://example.com/my_mustache_hook"
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
```
POST /my_mustache_hook HTTP/1.1
Astarte-Realm: test
Content-Length: 63
Content-Type: text/plain
Host: example.com
User-Agent: hackney/1.13.0

Device ydqBlFsGQ--xZ-_efQxuLw just connected from IP 172.18.0.1
```

## Relationship with Channels

Channels are part of AppEngine, and allow users to monitor device events through WebSockets, on top
of [Phoenix Channels](https://hexdocs.pm/phoenix/channels.html). Under the hood, Channels use
transient triggers to define which kind of events will flow through a specific room.
