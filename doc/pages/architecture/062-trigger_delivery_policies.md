# Trigger Delivery Policies

When an [HTTP action](060-triggers.html#http-actions) is triggered, an event is sent to a specific URL.
However, it is possible that the request is not successfully completed, e.g. the required resource is momentarily not available.
Trigger Delivery Policies (also referred to as *policies* or *delivery policies*) specify what to do in case of delivery errors
and how to handle events which have not been successfully delivered.
In the same fashion as triggers and interfaces, policies are realm-scoped objects, too.

While a trigger may specify at most one delivery policy, there is no upper bound on the number of triggers handled by the same policy.

Under the hood, a policy is mapped to a queue on which the events to be delivered are stored.
This queue is referred to as *event queue* and has a 1-to-1 relationship to the policy,
i.e. there is one and only one event queue for each delivery policy.
The size of the event queue is given in the policy specification.
This provides an upper bound on the amount of space the event queue can fill.

In the context of a policy, the strategy to handle delivery errors is describe by a list of *error handlers*,
which specify how to react to an error (e.g. resend or discard the event) and what kind of error is to be handled.
Each policy specifies at least one error handler. 
Every event in the event queue can be resent up to a number of times given in the policy specification.

## Trigger Delivery Policy Components

A Trigger Delivery Policy is composed of:

- Name: a string of at most 127 characters, unique for each realm. Names starting with "`?`", "`!`", or "`@`" are reserved.
  This is a required component and uniquely identifies the policy in the realm.
  
- Error handlers: a non-empty list of handlers. 
  Each handler acts on groups of delivery errors and describes the strategy Astarte should take when they occur.
  In pseudo-BNF syntax, an handler is described by the following grammar:
  ```
    handler ::= "{"
        "on" ":" "client_error" | "server_error" | "any_error" | [<int>] ","
        "strategy" ":" "discard" | "retry"
    "}"
  ```
  There are two possible strategies: either discard the event or retry. If the strategy is `retry`, events will be requeued in the event queue.
  The default retry strategy is discarding events.
  The `on` field specifies the group of HTTP errors the handler refers to: client errors (400-499), server errors (500-599), all errors (400-599), or a custom range of error codes (e.g. `[418, 419, 420]`).
  Handlers can be at most 200 and must be not overlapping (i.e. there can not be two handlers which refer to at least one shared error code).
  
- Maximum capacity: the maximum size of the event queue which refers to the policy.
  If the number of messages to be retried exceeds the event queue size, older events will be discarded.

- Retry times: the maximum number of times an event in the event queue can be resent.
  A single policy does not allow to retry sending events for different amount of times, but different policies may have different numbers.
  This is optional, but required if the policy specifies at least one handler with retry strategy.

- Event TTL: in orer to further lower the space requirement of the event queue, events may be equipped with a TTL which specifies the amount of
  milliseconds an event is retained in the event queue. When an event expires, it is discarded from the event queue, even if it has not been
  delivered. This is optional.

## Known issues

At the moment, Trigger Delivery Policies in general do not provide a guarantee of in-order delivery of events.
If the `retry` strategy is specified, in-order delivery cannot be guaranteed because a > 1 consumer prefetch count is being used. This allows for higher throughput at the cost of consistency.
An experimental feature allows to set the maximum number of messages that can be dequeued concurrently from the event queue
using AMQP (RabbitMQ) [consumer prefetch count](https://www.rabbitmq.com/consumer-prefetch.html). When prefetch count is set to 1, events are processed in order. Higher values allow for higher throughput by relaxing the ordering guarantee.
This feature is disabled by default.

Moreover, Trigger Delivery Policies do not provide a guarantee of in-order delivery of events if the Astarte Trigger Engine component
is replicated (event when the policy prefetch count is set to 1), as data from event queues are delivered to consumers in a round-robin fashion.

Note that, since previous Astarte versions (i.e. < 1.1) did not provide a retry mechanism for events, both issues do
not impact the expected behaviour if Trigger Delivery Policies are not used.