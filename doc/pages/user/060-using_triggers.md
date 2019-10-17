# Using Triggers

Triggers allow receiving notifications when a device connects, disconnects or publishes specific
data.

This page will show two practical examples regarding triggers. For more detailed documentation,
showing all possible trigger conditions and actions, check the [Triggers](060-triggers.html) page.

The examples use [`astartectl`](https://github.com/astarte-platform/astartectl) but you can manage
triggers also from [Realm Management
API](api/index.html?urls.primaryName=Realm%20Management%20API#/trigger).

## Connection Trigger

This trigger will send a `POST` request to `<post-url>` every time any device connects to its
transport.

This is the JSON representation of the trigger

```json
{
    "name": "my_connection_trigger",
    "action": {
        "http_post_url": "<post-url>"
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

Assuming the above JSON is contained in `my_connection_trigger.json`, you can install the trigger
using astartectl:

```
astartectl realm-management triggers install my_connection_trigger.json \
  -k <realm-key> -r <realm_name> -u <astarte-api-url>
```

Now, when a device connects, `<post-url>` will receive the following JSON payload:

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

## Data Trigger

This trigger will send a `POST` request to `<post-url>` every time a device sends data to the
`org.astarteplatform.Values` major version `0` interface on the `/realValue` path.

This is the JSON representation of the trigger
```json
{
    "name": "my_data_trigger",
    "action": {
        "http_post_url": "<post-url>"
    },
    "simple_triggers": [
        {
            "type": "data_trigger",
            "on": "incoming_data",
            "interface_name": "org.astarteplatform.Values",
            "interface_major": 0,
            "match_path": "/realValue",
            "value_match_operator": "*"
        }
    ]
}
```

Assuming the above JSON is contained in `my_data_trigger.json`, you can install the trigger
using astartectl:

```
astartectl realm-management triggers install my_data_trigger.json \
  -k <realm-key> -r <realm_name> -u <astarte-api-url>
```

When a device sends data to the interface/path defined above, `<post-url>` will receive the
following JSON payload:

```json
{
  "timestamp": "<timestamp>",
  "device_id": "<device_id>",
  "event": {
    "type": "incoming_data",
    "interface": "org.astarteplatform.Values",
    "path": "/realValue",
    "value": <value>
  }
}
```
