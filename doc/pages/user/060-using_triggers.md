<!--
Copyright 2019-2022 SECO Mind Srl

SPDX-License-Identifier: Apache-2.0
-->

# Using Triggers

Triggers allow receiving notifications when a device connects, disconnects or publishes specific
data. More details on Triggers can be found in the [Architecture Documentation](060-triggers.html).

Astarte allows you to install and delete Triggers dynamically through its clients. Upon installation
or deletion, changes to the Trigger infrastructure might take some time to propagate, and some devices
might pick up changes at a later time. If a Trigger shows as installed, it will eventually be
loaded. This propagation can take up to 10 minutes.

## Listing Triggers

At any time, you can list existing Triggers in a Realm and fetch their details and definitions.

### Listing and querying Triggers using Astarte Dashboard

After logging in, navigate to the Triggers page using the menu on the left. The list of Triggers
installed in the Realm will be shown in the page. Clicking on a Trigger will open the Trigger
editor in view-only mode, showing its definition on the right panel.

### Listing and querying Triggers using astartectl

To list all existing Triggers in a Realm:

```bash
$ astartectl realm-management triggers list
[my_trigger other_trigger my_connection_trigger my_data_trigger]
```

To get a Trigger definition:

```bash
$ astartectl realm-management triggers show my_connection_trigger
{
  "name": "my_connection_trigger",
  "action": {
      "http_url": "<url>",
      "http_method": "<method>"
  },
  "simple_triggers": [
      {
          "type": "device_trigger",
          "device_id": "*",
          "on": "device_connected"
      }
  ]
}
```

### Listing and querying Triggers using Realm Management API

To list all existing Triggers in a Realm:

`GET api.<astarte base URL>/realmmanagement/v1/<realm name>/triggers`

```json
{
  "data": [
    "my_trigger",
    "other_trigger",
    "my_connection_trigger",
    "my_data_trigger"
  ]
}
```

To get a Trigger definition:

`GET api.<astarte base URL>/realmmanagement/v1/<realm name>/triggers/my_connection_trigger`

```json
{
  "data": {
    "name": "my_connection_trigger",
    "action": {
        "http_url": "<url>",
        "http_method": "<method>"
    },
    "simple_triggers": [
        {
            "type": "device_trigger",
            "device_id": "*",
            "on": "device_connected"
        }
    ]
  }
}
```

## Installing a Trigger

To install a Trigger, you need its JSON definition. If you have access to the Astarte Dashboard, you
can use its Trigger Editor to build your JSON definition and install the Trigger directly. If you
already have a JSON definition instead, you can either use `astartectl` or Realm Management APIs.

The name of the Trigger must be unique within the Realm, or an error will be returned.

### Installing a Trigger using Astarte Dashboard

After logging in, navigate to the Triggers page using the menu on the left. Click on
"Install a new Trigger..." in the top-right corner. The Trigger Editor will open, and you can
either paste/write a JSON definition, or use the declarative editor.

When you are done, click on the "Install Trigger" button at the bottom of the declarative editor
to install the Trigger in the Realm.

### Installing a Trigger using astartectl

Assuming the Trigger definition is contained in `my_connection_trigger.json`,

```bash
$ astartectl realm-management triggers install my_connection_trigger.json
ok
```

### Installing a Trigger using Realm Management APIs

`POST api.<astarte base URL>/realmmanagement/v1/<realm name>/triggers`

The POST request must have the following request body, with content type `application/json`

```json
{
  "data": {
    "name": "my_connection_trigger",
    "action": {
        "http_url": "<url>",
        "http_method": "<method>"
    },
    "simple_triggers": [
        {
            "type": "device_trigger",
            "device_id": "*",
            "on": "device_connected"
        }
    ]
  }
}
```

## Deleting a Trigger

To delete a Trigger, you need to know its name. Just like when installing a Trigger, deleting a Trigger
might not stop the data flow out of the Trigger immediately, which will eventually terminate at some
point.

### Deleting a Trigger using Astarte Dashboard

After logging in, navigate to the Triggers page using the menu on the left. Click on
"Install a new Trigger..." in the top-right corner. Click on the Trigger name you want to delete.
The Trigger Editor will open, and a "Delete" button will become available next to the Trigger
name. Click on it to delete the Trigger.

### Deleting a Trigger using astartectl

```bash
$ astartectl realm-management triggers delete my_connection_trigger
ok
```

### Deleting a Trigger using Realm Management APIs

`DELETE api.<astarte base URL>/realmmanagement/v1/<realm name>/triggers/my_connection_trigger`

## Trigger examples

This section outlines two examples for the two main Trigger types (connection and data), and a
sample payload for its HTTP Post URL action.

### Connection Trigger

This trigger will send a `POST` request to `<url>` every time any device connects to its
transport.

This is the JSON representation of the trigger:

```json
{
    "name": "my_connection_trigger",
    "action": {
        "http_url": "<url>",
        "http_method": "post"
    },
    "simple_triggers": [
        {
            "type": "device_trigger",
            "device_id": "*",
            "on": "device_connected"
        }
    ]
}
```

If the Trigger is installed, when a device connects, `<url>` will receive the following JSON payload:

```json
{
  "timestamp": "<timestamp>",
  "device_id": "<device_id>",
  "event": {
    "type": "device_connected",
    "device_ip_address": "<device_ip_address>"
  }
}
```

### Data Trigger

This trigger will send a `POST` request to `http://www.example.com/hook` every time a device sends data to the
`org.astarte-platform.genericsensors.Values` major version `0` interface on the `/streamTest/value` path.

This is the JSON representation of the trigger

```json
{
    "name": "my_data_trigger",
    "action": {
        "http_url": "http://www.example.com/hook",
        "http_method": "post"
    },
    "simple_triggers": [
        {
            "type": "data_trigger",
            "on": "incoming_data",
            "interface_name": "org.astarte-platform.genericsensors.Values",
            "interface_major": 0,
            "match_path": "/streamTest/value",
            "value_match_operator": "*"
        }
    ]
}
```

If the Trigger is installed, when a device sends data to the interface/path defined above,
`<url>` will receive the following JSON payload:

```json
{
  "timestamp": "<timestamp>",
  "device_id": "<device_id>",
  "event": {
    "type": "incoming_data",
    "interface": "org.astarte-platform.genericsensors.Values",
    "path": "/streamTest/value",
    "value": <value>
  }
}
```

## Restricting triggers to a single device or group

Both device and data triggers accept the `device_id` and `group_name` keys to restrict a trigger to
a single device or a single group.

Triggers containing the `device_id` key will be triggered only for the specified device, while
triggers containing the `group_name` key will be triggered only if the device is member of the group
that is indicated in the `group_name` key. Note that when devices in a group are added or removed,
the changes are not reflected immediately in group triggers. It can take up to 10 minutes to see the
propagation of said changes.

## Trigger Delivery Policies

[Trigger Delivery Policies](062-using_trigger_delivery_policies.html) allow customizing what Astarte is supposed to do in case of delivery errors
on HTTP events and how to handle events that have not been delivered.
A Trigger can be linked to one (at most) Trigger Delivery Policy by specifying the name of the policy in the `"policy"` field.
If no Trigger Delivery Policies are specified, Astarte will resort to the default (pre v1.1) behaviour, i.e. ignoring delivery errors.
Note that the Trigger Delivery Policy must be installed before installing a Trigger that is linked to it, or an error will be returned.
The following is an example of a Connection Trigger linked to the `simple_trigger_delivery_policy` Trigger Delivery Policy:

```json
{
    "name": "my_connection_trigger",
    "action": {
        "http_url": "<url>",
        "http_method": "post"
    },
    "simple_triggers": [
        {
            "type": "device_trigger",
            "device_id": "*",
            "on": "device_connected"
        }
    ],
    "policy" : "simple_trigger_delivery_policy"
}
```

Refer to the [relevant documentation](062-using_trigger_delivery_policies.html) for more information on Trigger Delivery Policies.