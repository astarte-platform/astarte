# Triggers

Triggers in Astarte are the go-to mechanism for generating push events. In contrast with AppEngine's REST APIs, Triggers allow users to specify conditions upon which a custom payload is delivered to a recipient, using a specific `action`, which usually maps to a specific transport/protocol, such as HTTP.

Each trigger is defined by two main components: `condition` and `action`.

## Condition

A condition defines the event (or chain of events) upon which an action is triggered. Astarte monitors incoming events and triggers a corresponding action whenever there is a match.

## Action

Actions are triggered by a matching condition. An Action defines how the event should be sent to the outer world (e.g. an http POST on a certain URL). In addition, most actions have a Payload, which carries the body of the event.

Payloads are most of the time plain-text, and Astarte provides several ways to generate them. By default Astarte generates a JSON payload with all the relevant information of the event. This is also the format used when delivering payloads in Astarte Channels. The format for each payload can be found in the [simple events encoder](https://github.com/astarte-platform/astarte_core/blob/master/lib/astarte_core/triggers/simple_events/encoder.ex). In the foreseeable future, more user friendly documentation about `json` payloads will be provided.

Astarte also provides a powerful templating mechanism for plain-text payloads based on top of [Mustache](https://mustache.github.io/). This is especially useful for integrating with third-party actors which require custom payload formats.

Given this kind of flexibility, triggers are the most powerful way to push data to an external service, potentially without any additional customization.

## Relationship with Channels

Channels are part of AppEngine, and allow users to monitor device events through WebSockets, on top of [Phoenix Channels](https://hexdocs.pm/phoenix/channels.html). Under the hood, Channels use transient triggers to define which kind of events will flow through a specific room.
