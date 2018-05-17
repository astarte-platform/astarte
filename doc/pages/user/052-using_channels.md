# Using Astarte Channels

Especially when building Frontend applications, it is useful to receive real-time updates about data sent from Devices. Astarte leverages [Phoenix Channels](https://hexdocs.pm/phoenix/channels.html) to provide such a thing over [WebSockets](https://en.wikipedia.org/wiki/WebSocket) in AppEngine API. WebSockets can be used natively from a Web Browser and follow the same authentication pattern as a standard HTTP call.

Astarte Channels define a semantic on top of Phoenix Channels which allows read-only monitoring of `device` Interfaces. Authentication and Authorization over Channels happens in the very same way as `AppEngine`, and the `a_ch` claim in the token is respected when joining rooms and installing triggers. See [Authentication and Authorization](070-auth.html) for more details on Auth semantics in Astarte.

## Rooms

Rooms in Astarte Channels map 1:1 to Topics in Phoenix Channels, and can be joined in the very same way. Once a connection is established, the user can join any number of rooms, given he is [authorized to do so](#authorization).

A Room is identified by a topic with the following semantics: `rooms:<realm>:<name>`. For example, `rooms:test:myroom` will join the Room `myroom` in the Realm `test`.

A room can be joined by any number of concurrent users. Rooms serve as containers for Transient Triggers, which can be installed by any authorized user. Transient Triggers are actual [Triggers](060-triggers.md), with the difference that they exist within a Channels Room rather than within a Realm - this mostly affects their timespan - and that the `action` can't be configured - every time a Condition is triggered a message is delivered to users in the Room, [in a well-known format](https://github.com/astarte-platform/astarte_core/tree/master/lib/astarte_core/triggers/simple_events).

### Events

Everytime a Condition of an installed Trigger is triggered, an event is sent to the Phoenix Channel, with a similar payload:

```json
{
	"device_id": "f0VMRgIBAQAAAAAAAAAAAA",
	"event": {
		"type": "device_connected",
		"device_ip_address": "1.2.3.4"
	}
}
```

`device_id` is always present (as long as the trigger matches a device) and identifies the device emitting the event. `event`, instead, depends on the kind of installed trigger. It always carries a `type` string, which identifies the content of the object. Currently, the documentation of every event's payload can be found in [Astarte's protobuf files](https://github.com/astarte-platform/astarte_core/tree/master/lib/astarte_core/triggers/simple_events). However, there are some discrepancies in mapping (e.g.). It is advised also to have a look at the [encoder](https://github.com/astarte-platform/astarte_core/blob/master/lib/astarte_core/triggers/simple_events/encoder.ex). In the foreseeable future, more user friendly documentation will be provided.

### Lifecycle

Once a room is created, it remains valid and active with all of its subscriptions. There's little overhead in having a large number of rooms, as the only components leeching resources are Transient Triggers. As of today, Transient Triggers never expire - it is responsibility of the user to clean them up once the room becomes empty, if needed. In future versions, Transient Triggers will likely expire after some time, if left in an empty room.

## Managing Transient Triggers

To install a Transient Trigger, one should issue a `watch` event in the Channel, given he is authorized to do so. The payload of such an event is identical to a Trigger definition, hence it looks like this:

```json
{
    "name": "datatrigger",
    "device_id": "f0VMRgIBAQAAAAAAAAAAAA",
    "simple_trigger": {
        "type": "data_trigger",
        "on": "incoming_data",
        "interface_name": "org.astarteplatform.Values",
        "interface_major": 0,
        "match_path": "/realValue",
        "value_match_operator": ">",
        "known_value": 0.6
    }
}
```

This installs in the Room a Transient Trigger which will trigger an event everytime a value higher than `0.6` is sent on the path `/realValue` of the `datastream` interface `org.astarteplatform.Values` by the device `f0VMRgIBAQAAAAAAAAAAAA`, and will be received by every user currently in the room. If a user isn't in the room at the time of the event, he will not get it, and there's no way he can retrieve it if he joined at a later time.

Triggers can be uninstalled by issuing an `unwatch` event in the Channel. The payload of the event should be the name of the trigger which should be uninstalled.

## Authorization

Just like any other Astarte component, Authorization is encapsulated in a token claim, in particular the `a_ch` claim. However, the mechanism is rather different compared to a REST API, and uses different verbs.

### JOIN

The `JOIN` verb implies that a user can join a room. This only allows him to receive events and to interact in a *read-only* fashion with the room itself. There is no restriction to which events a user sees - if he is authorized to enter in a room, he will be capable of seeing all events flowing in. More granular permissions can be done simply by creating more rooms in which different triggers will be installed.

The `JOIN` verb has the following semantic: `JOIN::<regex>`, where regex matches a room name (the room name is what follows `rooms:<realm>:` - the realm is implicit in the context of the authorization token). For example, a user authorized with the `JOIN::test.*` claim in the `test` realm will be able to join, for example, `rooms:test:testthis`, `rooms:test:testme`, `rooms:test:test`. The realm is always implicit in the regex, as the token is authenticated in the context of a Realm.

### WATCH

The `WATCH` verb allows a user to install a Trigger within a room. Its semantics define which kind of trigger, and upon which entities the user is allowed to act. Watch semantics are `WATCH::<regex>`, where `regex` is a regular expression which matches a device, path or interface (or a mixture of them) in almost very same fashion as the `a_aea` claim (which is used in AppEngine).

Given different kind of triggers impact different Astarte entities, the Authorization claim implicitly defines which kind of triggers a user will be able to install. For example, `f0VMRgIBAQAAAAAAAAAAAA/org.astarteplatform.Values.*` will allow installing data triggers such as the one shown in the previous example, but won't let the user install device-wide triggers (such as connect/disconnect events). A claim such as `f0VMRgIBAQAAAAAAAAAAAA` or `f0VMRgIBAQAAAAAAAAAAAA.*`, instead, will allow device-level triggers to be installed.
