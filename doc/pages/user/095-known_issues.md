# Known issues

This page collects some notable issues which affect Astarte `v1.0`. This is by no means an
exhaustive list and you should also check [Github issues](https://github.com/astarte-platform/astarte/issues) to see if your problem is already
covered there.

## Realm deletion

Astarte `v1.0` introduces the possibility of deleting a Realm, but currently devices which have a
valid certificate are not disconnected from the Realm. The issue is tracked
[here](https://github.com/astarte-platform/astarte/issues/443).

Since publishing with devices on unexisting realms can cause problems (namely: RabbitMQ data queues
filling up) which can also impact devices on other realms, a realm should be deleted only after
ensuring that no devices are connected to it.

Due to the problems that realm deletion can cause, currently the feature must be explicitly enabled
with a feature gate, i.e. by adding

```yaml
features:
  realmDeletion: true
components: ...
```

to the Astarte Custom Resource (which maps to setting the `HOUSEKEEPING_ENABLE_REALM_DELETION`
environment variable to `true` in the `astarte_housekeeping` container).

We also encourage avoiding to recreate realms with the same name to avoid having devices from the
old realm reconnecting back to the new one.

## Group permissions

Currently Astarte [authorization mechanism](070-auth.html) doesn't allow permissions on groups with
a device granularity. Specifically there's no way to authorize a user to add only specific devices
to a group. The issue is tracked [here](https://github.com/astarte-platform/astarte/issues/463).

This means that right now the best way to allow users to add or remove devices from a group they
have access to is to provide a backend which is able to perform the necessary authorization checks
and then performs the necessary additions/removals, while the user only has a read access to the
group resource.

In the long term a minor semantic change is going to employed, therefore currently we discourage
emitting long living tokens which allow a non-root user to manage groups (i.e. create and modify
them) since the current tokens could become incompatible with future changes.

## Ghost connected devices

In some circumstances, prior to Astarte `v1.0`, a device might be mistakenly reported as connected.
This bug has been fixed in `v1.0`, however this bug may still affect devices that have connected
last time while using `v0.11` (prior to the upgrade to `v1.0`).
This issue is likely to happen when upgrading to `v1.0` since it might be caused by VerneMQ
shutdown.
A device reconnection fixes this issue, and the connection state will always be reliably reported.
