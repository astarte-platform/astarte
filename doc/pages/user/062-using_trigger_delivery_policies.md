<!--
Copyright 2022-2023 SECO Mind Srl

SPDX-License-Identifier: Apache-2.0
-->

# Using Trigger Delivery Policies

*Note: Trigger Delivery Policies are an experimental feature, see [Known Issues](#known-issues) for more information about their current status.*

Trigger Delivery Policies allow customizing what Astarte is supposed to do in case of delivery errors on HTTP events
and how to handle events that have not been delivered. More details on Trigger Delivery Policies can be found in the [Architecture Documentation](062-trigger_delivery_policies.html).

Astarte allows you to install and delete Trigger Delivery Policies dynamically through its clients.
A Trigger Delivery Policy is linked to an [HTTP Trigger](060-using_triggers.html) by specifying its name in the Trigger definition.
A Trigger can be linked to at most one Trigger Delivery Policy, but a single Trigger Delivery Policy may serve any number of Triggers.

## Listing Trigger Delivery Policies

At any time, you can list existing Trigger Delivery Policies in a Realm and fetch their details and definitions.

### Listing and querying Trigger Delivery Policies using Realm Management API

To list all existing Trigger Delivery Policies in a Realm:

`GET api.<your astarte domain>/realmmanagement/v1/<realm name>/policies`

```json
{
  "data": [
    "my_trigger_delivery_policy",
    "simple_trigger_delivery_policy",
    "other_trigger_delivery_policy",
    "retry_upon_all_errors_delivery_policy"
  ]
}
```

To get a Trigger Delivery Policy definition:

`GET api.<your astarte domain>/realmmanagement/v1/<realm name>/policies/simple_trigger_delivery_policy`

```json
{
  "data": {
    "name" : "simple_trigger_delivery_policy",
    "maximum_capacity" : 100,
    "error_handlers" : [
        {
            "on" : "any_error",
            "strategy" : "discard"
        }
    ]
  }
}
```

## Installing a Trigger Delivery Policy

To install a Trigger Delivery Policy, you need its JSON definition. Then you can install the Trigger Delivery Policy via Realm Management APIs.

The name of the Trigger Delivery Policy must be unique within the Realm, or an error will be returned.

### Installing a Trigger Delivery Policy using Realm Management APIs

`POST api.<your astarte domain>/realmmanagement/v1/<realm name>/policies`

The POST request must have the following request body, with content type `application/json`

```json
{
  "data": {
    "name" : "simple_trigger_delivery_policy",
    "maximum_capacity" : 100,
    "error_handlers" : [
        {
            "on" : "any_error",
            "strategy" : "discard"
        }
    ]
  }
}
```

## Deleting a Trigger Delivery Policy

To delete a Trigger Delivery Policy, you need to know its name.
A Trigger Delivery Policy can be deleted only if no Triggers linked to it are present in the Realm.

### Deleting a Trigger Delivery Policy using Realm Management APIs

`DELETE api.<your astarte domain>/realmmanagement/v1/<realm name>/policies/simple_trigger_delivery_policy`

## Trigger Delivery Policy examples

This section outlines two examples of Trigger Delivery Policy.

### A Simple Trigger Delivery Policy

The following Trigger Delivery Policy discards events on any error.
This is the only behaviour previous Astarte versions (i.e. < 1.1) allowed.

```json
{
    "name" : "simple_policy",
    "maximum_capacity" : 100,
    "error_handlers" : [
        {
            "on" : "any_error",
            "strategy" : "discard"
        }
    ]
}
```

### A More Complex Trigger Delivery Policy

The following policy has a different behaviour depending on whether the HTTP delivery error is a client or a server one. 

```json
{
    "name" : "complex_policy",
    "maximum_capacity" : 100,
    "error_handlers" : [
            {
                "on" : "server_error",
                "strategy" : "retry"
            },
            {
                "on" : "client_error",
                "strategy" : "discard"
            }
        ],
    "retry_times" : 5,
    "event_ttl" : 10
}
```

If an HTTP client error occurs, then Astarte will try to resend the event up to 5 times.
If there occurs an HTTP server error, then Astarte will do nothing. 
At most 100 events can be in the queue at any time; if more than 100 events are present in the queue, the oldest ones will be deleted (even if they were resent less than 5 times in the case of HTTP client errors). If any event lasts for longer than 10 second in the queue, it will be discarded.

## Known issues

At the moment, trigger delivery policies in general do not provide a guarantee of in-order delivery of events.
Refer to the [Architecture Documentation](062-trigger_delivery_policies.html#known-issues) for more information on this.