# Upgrading the Cluster

This section describes the manual steps required to upgrade an Astarte cluster. These steps are not
necessary if you're using Astarte Kubernetes Operator, which will take care of performing these
steps during an upgrade.

## Upgrading v0.10 to v0.11

### Create the `grouped_devices` table
For every realm, execute this query on your Cassandra instance

```
CREATE TABLE <realm_name>.grouped_devices (
   group_name varchar,
   insertion_uuid timeuuid,
   device_id uuid,
   PRIMARY KEY ((group_name), insertion_uuid, device_id)
);
```

### Add new columns to `devices` table
For every realm, execute this query on your Cassandra instance

```
ALTER TABLE <realm_name>.devices
ADD (groups map<text, timeuuid>,
    exchanged_bytes_by_interface map<frozen<tuple<ascii, int>>, bigint>,
    exchanged_msgs_by_interface map<frozen<tuple<ascii, int>>, bigint>);
```
