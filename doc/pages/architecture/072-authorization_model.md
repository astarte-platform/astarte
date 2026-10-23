# Authorization Model

> **Status.** This page describes the target relationship-based authorization model, not what the
> whole cluster does today. Astarte's REST APIs are still authorized by the path based regular
> expressions carried in token claims, described in [Authentication and Authorization](070-auth.html#authorization). Only Pairing's GraphQL API currently authorizes
> against this model, and it implements a subset of it. The two systems are expected to coexist
> while GraphQL APIs land service by service.

Path based authorization puts the whole policy inside the token: a set of regular expressions, one
per API, which Astarte matches against the request path. It works, and it needs no durable storage,
but it has two limits that become pressing as the API surface grows. Permissions cannot be shared
between users, because there is nothing to share them through, and the policy is invisible to the
cluster: Astarte can tell you whether a token allows a request, never who is allowed to do what.

The authorization model described here replaces the regular expressions with
[relationship-based access control](https://openfga.dev/docs/modeling/getting-started) evaluated by
[OpenFGA](https://openfga.dev). The token still carries the identity; the permissions live in the
cluster.

## Identities

The principal is identified by the `sub` claim of the verified token, exactly as before. The
identity is **scoped to the authentication realm that verified the token**:

- `user:<realm>/<sub>` for a token verified with a realm's public key
- `user:_cluster/<sub>` for a token verified against Housekeeping's own authentication realm

The qualification is not cosmetic. Realms are separate authentication realms by design, each with
its own public key, so two realms may well use different identity providers, and nothing prevents
both from issuing the same `sub`. An unqualified identity would let a grant in one realm be honored
in another.

The same reasoning applies to every object: a device id is only unique within a realm, so objects
are realm-qualified too. Realm names match `^[a-z][a-z0-9]{0,47}$` and cannot contain a separator,
which makes `/` unambiguous:

```text
realm:testrealm
device:testrealm/f0VMRgIBAQAAAAAAAAAAAA
interface:testrealm/com.my.Commands
device_group:testrealm/production-line-4
```

## Object types

Astarte's resources already form a containment tree, and the model follows it:

```text
cluster                      the Astarte instance, Housekeeping's scope
└── realm                    the unit of tenancy, with its own public key
    ├── interface            name and major version
    ├── trigger
    ├── trigger_policy
    ├── device_group ──┐     Astarte's named device sets
    └── device       ←─┘     a device belongs to many device groups
```

Two more types carry no Astarte resource. `user` is the principal above, and `team` groups users so
that permissions can be granted to a set of people rather than to each of them:

```text
type team
  relations
    define member: [user, team#member]
```

Teams nest, so an organization can model its own structure without Astarte knowing anything about
it.

Note the deliberate naming: a **`team`** is a set of users, while a **`device_group`** is
[Astarte's group of devices](065-groups.html). The two are unrelated, and the distinction matters
because device groups are what make fleet-scoped permissions cheap: granting a role on one device
group scopes a user to a slice of the fleet without writing a tuple per device.

## Roles and capabilities

Relations come in two kinds, and the difference is the center of the model.

A **role** is directly assignable. It is what a tuple writes, and it is the only thing an
administrator ever grants:

```text
define fleet_manager: [user, team#member] or admin
```

A **capability** is derived by the model from roles, never assigned. It is what a service checks:

```text
define can_register_device: fleet_manager
```

So granting realm administration is one tuple rather than one tuple per operation, and the mapping
from roles to capabilities lives in the model, where it can be reviewed, instead of being implied by
whichever tuples happen to exist. Adding an operation means adding a capability to the model, not
migrating tuples.

The naming convention follows from the split: **capabilities are `can_<verb>_<noun>`, roles are
bare nouns**. Reading a relation tells you which kind it is.

### Roles

Nine roles cover the API surface. The four marked below can also be granted on a single device group
or a single device, which is where fleet granularity comes from.

| Role                | Scope                                           | Purpose                                                                     |
| ------------------- | ----------------------------------------------- | --------------------------------------------------------------------------- |
| `admin`             | cluster, realm                                  | Everything in its scope, including realm configuration                      |
| `interface_manager` | realm, interface                                | Install, update and delete interfaces                                       |
| `trigger_manager`   | realm                                           | Manage triggers and trigger delivery policies                               |
| `fleet_manager`     | realm, device group, device                     | Register and unregister devices, manage their metadata and group membership |
| `data_writer`       | realm, device group, device, interface          | Send data to devices                                                        |
| `data_reader`       | realm, device group, device, interface          | Read device data, status and statistics                                     |
| `fdo_manager`       | realm                                           | Manage FDO owner keys and ownership vouchers                                |
| `fdo_viewer`        | realm                                           | Read FDO owner keys and ownership vouchers                                  |
| `observer`          | cluster, realm, device group, device, interface | Read-only access across its scope                                           |

Three asymmetries in that table are deliberate:

- **Replacing a realm's public key is `admin` only.** Whoever can change the realm's validation mean
  can mint tokens for the realm, so the capability is not bundled with any other work.
- **Erasing a device is `admin`, not `fleet_manager`.** Unregistering a device is reversible;
  deleting it through Realm Management destroys its data.
- **Deleting a realm belongs to a cluster administrator**, expressed as `admin from parent`, so a
  realm's own administrator cannot delete the realm.

## Device data and interfaces

Path based authorization can express _read and write only `com.my.monitoring.*`, on any device_,
because a path contains both the device and the interface. Relationship-based authorization cannot
do that in one check without an object per device and interface pair, which does not scale: ten
thousand devices and twenty interfaces would be two hundred thousand objects.

Instead, data access is **two checks, both of which must pass**. The same capability is checked
against two objects, and the service requires both:

```text
check(user, can_write_data, device:testrealm/f0VMRgIBAQAAAAAAAAAAAA)   which devices?
check(user, can_write_data, interface:testrealm/com.my.Commands)       which interfaces?
```

That makes the tuple count additive rather than multiplicative, and the two axes compose as
expected. A realm-wide `data_writer` plus a per-interface grant means one interface on every device;
a device group grant plus realm-wide interface access means every interface on those devices;
scoping both yields the intersection.

What this cannot express is a genuinely ragged matrix, where one interface is allowed on a device
that another is denied on, and vice versa. Should that be required, OpenFGA
[conditions](https://openfga.dev/docs/modeling/conditions) can carry the interface name as request
context.

In practice the pressure is lower than it looks, because Astarte interfaces are either device-owned
or server-owned, so an interface is already effectively read-only or write-only from a user's point
of view.

## Capability reference

Every authorizable operation, by service, with the capability and the object it is checked against.
Operations whose caller is a device authenticated by its credentials secret or by the FDO protocol
are outside this model: there is no user to check, and the secret is itself the authorization.

### Housekeeping

Housekeeping authenticates against the cluster's own realm, so its identities are distinct from
every realm's.

| Operation                         | Capability                | Object    |
| --------------------------------- | ------------------------- | --------- |
| List realms                       | `can_list_realms`         | `cluster` |
| Create realm                      | `can_create_realm`        | `cluster` |
| Read cluster replication defaults | `can_read_cluster_config` | `cluster` |
| Read realm                        | `can_read_realm`          | `realm`   |
| Update realm                      | `can_update_realm`        | `realm`   |
| Delete realm                      | `can_delete_realm`        | `realm`   |

### Realm Management

| Operation                          | Capability                  | Object           |
| ---------------------------------- | --------------------------- | ---------------- |
| List interfaces                    | `can_list_interfaces`       | `realm`          |
| Install interface                  | `can_install_interface`     | `realm`          |
| List an interface's major versions | `can_read`                  | `interface`      |
| Read interface                     | `can_read`                  | `interface`      |
| Update draft interface             | `can_update`                | `interface`      |
| Delete interface                   | `can_delete`                | `interface`      |
| Read realm authentication config   | `can_read_realm_config`     | `realm`          |
| Replace realm public key           | `can_update_realm_config`   | `realm`          |
| Read device registration limit     | `can_read_realm_config`     | `realm`          |
| Read datastream storage retention  | `can_read_realm_config`     | `realm`          |
| List triggers                      | `can_list_triggers`         | `realm`          |
| Create trigger                     | `can_create_trigger`        | `realm`          |
| Read trigger                       | `can_read`                  | `trigger`        |
| Delete trigger                     | `can_delete`                | `trigger`        |
| List trigger delivery policies     | `can_list_trigger_policies` | `realm`          |
| Create trigger delivery policy     | `can_create_trigger_policy` | `realm`          |
| Read trigger delivery policy       | `can_read`                  | `trigger_policy` |
| Delete trigger delivery policy     | `can_delete`                | `trigger_policy` |
| Delete device and erase its data   | `can_delete`                | `device`         |

### Pairing

| Operation                        | Capability            | Object   |
| -------------------------------- | --------------------- | -------- |
| Register device                  | `can_register_device` | `realm`  |
| Unregister device                | `can_unregister`      | `device` |
| Create or upload FDO owner key   | `can_manage_fdo`      | `realm`  |
| List FDO owner keys              | `can_read_fdo`        | `realm`  |
| List FDO owner keys by algorithm | `can_read_fdo`        | `realm`  |
| Read FDO owner key               | `can_read_fdo`        | `realm`  |
| List owner keys for a voucher    | `can_read_fdo`        | `realm`  |
| List ownership vouchers          | `can_read_fdo`        | `realm`  |
| Register ownership voucher       | `can_manage_fdo`      | `realm`  |

A device reading its own information, obtaining MQTT credentials, verifying them, or running the FDO
TO2 handshake authenticates with its credentials secret or its FDO session, and is not covered by
this model.

### AppEngine

Device **metadata** and device **data** are separate capabilities: an operator renaming devices
should not thereby be able to send them commands. The `/devices-by-alias` and
`/groups/.../devices` paths resolve to the same capabilities as the equivalent device paths.

| Operation                              | Capability                | Object                 |
| -------------------------------------- | ------------------------- | ---------------------- |
| Read device count statistics           | `can_read_stats`          | `realm`                |
| List devices                           | `can_list_devices`        | `realm`                |
| Read device status                     | `can_read`                | `device`               |
| Update aliases, attributes, inhibition | `can_update`              | `device`               |
| List a device's interfaces             | `can_read_data`           | `device`               |
| Read interface values                  | `can_read_data`           | `device` + `interface` |
| Write interface value                  | `can_write_data`          | `device` + `interface` |
| Delete interface value                 | `can_write_data`          | `device` + `interface` |
| List device groups                     | `can_list_device_groups`  | `realm`                |
| Create device group                    | `can_create_device_group` | `realm`                |
| Read device group                      | `can_read`                | `device_group`         |
| List devices in a device group         | `can_read`                | `device_group`         |
| Add device to a device group           | `can_update`              | `device_group`         |
| Remove device from a device group      | `can_update`              | `device_group`         |
| Join a channel room                    | `can_join_room`           | `realm`                |
| Watch a trigger on a room              | `can_watch`               | `realm` or `device`    |

Channels currently take their own claim with `JOIN` and `WATCH` verbs, described in
[Using Channels](052-using_channels.html#authorization). Both map onto the two capabilities above.

## The model

The authorization model is kept in the repository, at
`apps/astarte_auth/priv/authorization_model.fga`, and applied to the OpenFGA store by the
initialization container, so that it is reviewed like code.

```text
model
  schema 1.1

type user

type team
  relations
    define member: [user, team#member]

type cluster
  relations
    # roles
    define admin: [user, team#member]
    define observer: [user, team#member] or admin
    # capabilities
    define can_create_realm: admin
    define can_list_realms: observer
    define can_read_cluster_config: observer

type realm
  relations
    define parent: [cluster]

    # roles, the only relations a tuple ever writes
    define admin: [user, team#member] or admin from parent
    define interface_manager: [user, team#member] or admin
    define trigger_manager: [user, team#member] or admin
    define fleet_manager: [user, team#member] or admin
    define fdo_manager: [user, team#member] or admin
    define fdo_viewer: [user, team#member] or fdo_manager
    define data_writer: [user, team#member] or admin
    define observer: [user, team#member] or admin or observer from parent
    define data_reader: [user, team#member] or data_writer or observer

    # capabilities, derived and never assigned
    define can_read_realm: observer
    define can_update_realm: admin from parent
    define can_delete_realm: admin from parent
    define can_read_realm_config: observer
    define can_update_realm_config: admin

    define can_list_interfaces: observer or data_reader
    define can_install_interface: interface_manager

    define can_list_triggers: observer
    define can_create_trigger: trigger_manager
    define can_list_trigger_policies: observer
    define can_create_trigger_policy: trigger_manager

    define can_register_device: fleet_manager
    define can_list_devices: observer or data_reader
    define can_read_stats: observer or data_reader

    define can_list_device_groups: observer or data_reader
    define can_create_device_group: fleet_manager

    define can_read_fdo: fdo_viewer
    define can_manage_fdo: fdo_manager

    define can_join_room: data_reader
    define can_watch: data_reader

type device_group
  relations
    define realm: [realm]

    # a role granted here scopes a user to one slice of the fleet
    define fleet_manager: [user, team#member] or fleet_manager from realm
    define data_writer: [user, team#member] or data_writer from realm
    define observer: [user, team#member] or observer from realm
    define data_reader: [user, team#member] or data_writer or data_reader from realm

    define can_read: observer or data_reader
    define can_update: fleet_manager

type device
  relations
    define realm: [realm]
    define group: [device_group]

    # roles inherit from the realm and from every group the device belongs to,
    # and can also be granted on the device itself
    define admin: admin from realm
    define fleet_manager: [user, team#member] or fleet_manager from realm or fleet_manager from group
    define data_writer: [user, team#member] or data_writer from realm or data_writer from group
    define observer: [user, team#member] or observer from realm or observer from group
    define data_reader: [user, team#member] or data_writer or data_reader from realm or data_reader from group

    define can_read: observer or data_reader or fleet_manager
    define can_update: fleet_manager
    define can_unregister: fleet_manager
    define can_delete: admin
    define can_read_data: data_reader
    define can_write_data: data_writer
    define can_watch: data_reader

type interface
  relations
    define realm: [realm]

    # a role granted here scopes a user to one interface
    define interface_manager: [user, team#member] or interface_manager from realm
    define data_writer: [user, team#member] or data_writer from realm
    define observer: [user, team#member] or observer from realm
    define data_reader: [user, team#member] or data_writer or data_reader from realm

    define can_read: observer or data_reader or interface_manager
    define can_update: interface_manager
    define can_delete: interface_manager
    define can_read_data: data_reader
    define can_write_data: data_writer

type trigger
  relations
    define realm: [realm]
    define can_read: observer from realm
    define can_delete: trigger_manager from realm

type trigger_policy
  relations
    define realm: [realm]
    define can_read: observer from realm
    define can_delete: trigger_manager from realm
```

## Granting permissions

Making a user a realm administrator is a single tuple, and scoping a contractor to one production
line is two:

```text
# a realm administrator
user:testrealm/alice   admin         realm:testrealm

# a contractor who may send data only to the devices of one group
user:testrealm/bob     data_writer   device_group:testrealm/production-line-4

# an on-call team that can read everything in the realm
team:oncall#member     observer      realm:testrealm
user:testrealm/carol   member        team:oncall
```

Astarte has no user management of its own and does not expose an API for writing these tuples. Role
assignment is expected to be driven from the identity provider that issues the tokens, in keeping
with Astarte's design of keeping user management outside the cluster. See
[best practices for authentication](070-auth.html#best-practices).

## Failure behavior

An authorization check that cannot be completed is not a denial. Astarte distinguishes the two: a
check OpenFGA answers negatively denies the request, while a check that fails to complete because
OpenFGA is unreachable or answers unexpectedly fails the request as an internal error. A service
whose store id is not configured is a third case, reported as such rather than as a denial, so that
a missing store is not mistaken for a permissions problem; a service still starts without one, and
every check then fails. Authorization fails closed in all of these, which means OpenFGA sits in the
request path of every authorized operation in the cluster and should be monitored accordingly.
