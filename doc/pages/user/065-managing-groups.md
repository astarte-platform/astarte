# Managing Groups

Devices can be divided in groups to provide group-specific access to the APIs.

The examples below will use `astartectl` but you can achieve the same results using AppEngine API.

### Reserved group prefixes

Some prefixes are reserved for internal use. It's not possible to create groups with a name starting
with the `~` and `@` characters.

## Creating a group

You can create a group with astartectl with this command

```
astartectl appengine groups create mygroup <device_identifier>,<device_identifier> \
  -k <appengine-key> -r <realm-name> -u <astarte-api-url>
```

`device_identifier` can be a Device ID or an Alias, and you can put multiple devices by separating
them with a comma.

You can check the group was created by listing groups in your realm

```
astartectl appengine groups list -k <appengine-key> -r <realm-name> -u <astarte-api-url>
```

## Adding or removing a device to/from a group

Once you created a group, you can add or remove devices from it.

To add a device, use:

```
astartectl appengine groups devices add <device_identifier> \
  -k <appengine-key> -r <realm-name> -u <astarte-api-url>
```

To remove a device, use:

```
astartectl appengine groups devices remove <device_identifier> \
  -k <appengine-key> -r <realm-name> -u <astarte-api-url>
```

Keep in mind that a group exists as long as it has at least one device in it, so if you remove the
last device from a group, the group will cease to exist.

You can always check which devices are in a group with:

```
astartectl appengine groups devices list -k <appengine-key> -r <realm-name> -u <astarte-api-url>
```

## Accessing Devices in a group with Astarte AppEngine API

Once a device is in a group, you can access to its data on this URL:

```
https://<astarte-api>/appengine/v1/groups/<group_name>/devices/<device_id>
```

The hierarchy is exactly the same that is found under

```
https://<astarte-api>/appengine/v1/devices/<device-id>
```

which is [documented here](api/index.html?urls.primaryName=AppEngine API#/), but this makes it
possible to emit a JWT that only allows access to devices belonging to a specific group.
