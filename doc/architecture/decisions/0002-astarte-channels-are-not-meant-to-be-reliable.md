# 2. Astarte Channels are not meant to be reliable

Date: 2018-04-03

## Status

Accepted

## Context

Astarte Channels are a way to receive events of specific Astarte entities via
Websockets, leveraging Phoenix Channels and volatile Triggers.

Due to the way volatile Triggers are implemented, it would be necessary to
introduce a large overhead to guarantee that all the data is correctly
delivered to Astarte Channels.

## Decision

Since we already have a reliable way to receive the events of a given entity
(persistent Triggers), we will not guarantee that Astarte Channels are a
reliable source of events.

## Consequences

If Astarte components involved with Astarte Channels are subject to a crash or
an equivalent abnormal situation, there can be a window in which new events are
not received even if they match the volatile trigger that was installed for a
specific Astarte Channels Room.

As such, Astarte Channels must be used only in applications that can put up
with the loss of data once in a while.
