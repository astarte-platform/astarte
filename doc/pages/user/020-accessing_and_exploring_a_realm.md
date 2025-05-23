# Accessing and Exploring a Realm

In Astarte, a Realm is a logical partition which holds a number of devices and an Authentication
Realm.

The [Astarte Dashboard](015-astarte_dahsboard) allows you to explore all resources of a given Realm,
such as e.g. Interfaces, Triggers, Devices, Groups etc...

## Device limit in a Realm
While there is no limit on the number of Devices registered in a Realm, it is possible that an
upper bound has been set in the Realm configuration using the [Housekeeping API](/api/index.html?urls.primaryName=Housekeeping API).
When it is set, trying to register more Devices past the limit will result in an error.
The limit can be retrieved from Realm Management with

`GET <astarte base API URL>/realmmanagement/v1/<realm name>/config/device_registration_limit`

The HTTP payload of the response will have the following format:

```json
{
    "data": <value>
}
```

If such a limit is set, the value will be a non negative integer.
If not, the value will be `null`.
