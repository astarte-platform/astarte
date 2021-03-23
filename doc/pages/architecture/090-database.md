# Astarte Database

Astarte leverages [Cassandra](http://cassandra.apache.org/) to store all of its data, including data ingested from devices (which might scale to insane amounts). Cassandra offers scalability and high availability with [good performances](https://www.datastax.com/apache-cassandra-leads-nosql-benchmark).
Cassandra offers linear scalability and can span from really small clusters to hundreds of nodes, without compromising on reliability.
[ScyllaDB](https://www.scylladb.com/) >= 3.3 is also supported as a drop-in replacement when a [performance boost](https://www.scylladb.com/product/benchmarks/) is needed.

Cassandra is also the ideal storage for large-scale data processing with [Apache Spark](http://spark.apache.org/).

Astarte is multi-tenant by design, with each tenant mapping to an Astarte Realm. Each Realm has its own Cassandra keyspace, which can be tuned according to Realm-specific needs (e.g.: Realms might have different replication levels). For this reason, in the scope of this section, realm and keyspace can be used as synonyms, except for the `astarte` keyspace.

## Schema and Keyspace Creation

Astarte automatically takes care of keyspaces, tables creation and intra-version migrations (those tasks are performed by `astarte_housekeeping` or `astarte_realm_management`, depending on the context). The following documentation is just a reference about Astarte's internal statements, and is related to the release series referenced by the documentation.

### Astarte Keyspace

Astarte needs an `astarte` keyspace to store its own data.

`astarte` keyspace and tables are created with following [CQL](https://docs.datastax.com/en/cql/3.3/index.html) statements:

```sql
CREATE KEYSPACE astarte
  WITH replication = {'class': 'SimpleStrategy', 'replication_factor': <replication factor>}  AND
    durable_writes = true;
```

```sql
CREATE TABLE astarte.realms (
  realm_name varchar,

  PRIMARY KEY (realm_name)
);
```

### Realm Creation

Each realm needs several tables to store data for all the functionalities.
Realm tables can be grouped in the following functionalities:

* Configuration & key-value store
* Interfaces schema
* Device management
* Groups management
* Triggers storage
* Data storage

Some data storage tables might be created when required, whereas all other tables are created when a keyspace is created, using the following statements:

```sql
CREATE KEYSPACE <realm name>
  WITH replication = {'class': 'SimpleStrategy', 'replication_factor': :replication_factor} AND
    durable_writes = true;
```

```sql
CREATE TABLE <realm name>.kv_store (
  group varchar,
  key varchar,
  value blob,

  PRIMARY KEY ((group), key)
);
```

```sql
CREATE TABLE <realm name>.names (
  object_name varchar,
  object_type int,
  object_uuid uuid,

  PRIMARY KEY ((object_name), object_type)
);
```

```sql
CREATE TABLE <realm_name>.devices (
  device_id uuid,
  aliases map<ascii, varchar>,
  introspection map<ascii, int>,
  introspection_minor map<ascii, int>,
  old_introspection map<frozen<tuple<ascii, int>>, int>,
  protocol_revision int,
  first_registration timestamp,
  credentials_secret ascii,
  inhibit_credentials_request boolean,
  cert_serial ascii,
  cert_aki ascii,
  first_credentials_request timestamp,
  last_connection timestamp,
  last_disconnection timestamp,
  connected boolean,
  pending_empty_cache boolean,
  total_received_msgs bigint,
  total_received_bytes bigint,
  exchanged_bytes_by_interface map<frozen<tuple<ascii, int>>, bigint>,
  exchanged_msgs_by_interface map<frozen<tuple<ascii, int>>, bigint>,
  last_credentials_request_ip inet,
  last_seen_ip inet,
  attributes map<varchar, varchar>,

  groups map<text, timeuuid>,

  PRIMARY KEY (device_id)
);
```

```sql
CREATE TABLE <realm name>.grouped_devices (
  group_name varchar,
  insertion_uuid timeuuid,
  device_id uuid,
  PRIMARY KEY ((group_name), insertion_uuid, device_id)
);
```

```sql
CREATE TABLE <realm name>.endpoints (
  interface_id uuid,
  endpoint_id uuid,
  interface_name ascii,
  interface_major_version int,
  interface_minor_version int,
  interface_type int,
  endpoint ascii,
  value_type int,
  reliability int,
  retention int,
  expiry int,
  database_retention_ttl int,
  database_retention_policy int,
  allow_unset boolean,
  explicit_timestamp boolean,
  description varchar,
  doc varchar,

  PRIMARY KEY ((interface_id), endpoint_id)
);
```

```sql
CREATE TABLE <realm name>.interfaces (
  name ascii,
  major_version int,
  minor_version int,
  interface_id uuid,
  storage_type int,
  storage ascii,
  type int,
  ownership int,
  aggregation int,
  automaton_transitions blob,
  automaton_accepting_states blob,
  description varchar,
  doc varchar,

  PRIMARY KEY (name, major_version)
);
```

```sql
CREATE TABLE <realm name>.individual_properties (
  device_id uuid,
  interface_id uuid,
  endpoint_id uuid,
  path varchar,
  reception_timestamp timestamp,
  reception_timestamp_submillis smallint,

  double_value double,
  integer_value int,
  boolean_value boolean,
  longinteger_value bigint,
  string_value varchar,
  binaryblob_value blob,
  datetime_value timestamp,
  doublearray_value list<double>,
  integerarray_value list<int>,
  booleanarray_value list<boolean>,
  longintegerarray_value list<bigint>,
  stringarray_value list<varchar>,
  binaryblobarray_value list<blob>,
  datetimearray_value list<timestamp>,

  PRIMARY KEY((device_id, interface_id), endpoint_id, path)
);
```

```sql
CREATE TABLE <realm name>.simple_triggers (
  object_id uuid,
  object_type int,
  parent_trigger_id uuid,
  simple_trigger_id uuid,
  trigger_data blob,
  trigger_target blob,

  PRIMARY KEY ((object_id, object_type), parent_trigger_id, simple_trigger_id)
);
```

## Tables

### Devices

Devices table stores the list of all the devices for a certain realm and all their metadata, including the introspection, the device status and credentials information.

| Column Name                   | Column Type                           | Description                                                                                                                                                                                        |
|-------------------------------|---------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `device_id`                   | `uuid`                                | Device unique 128 bits ID.                                                                                                                                                                         |
| `aliases`                     | `map<ascii, varchar>`                 | Alias purpose and alias map.                                                                                                                                                                       |
| `introspection`               | `map<ascii, int>`                     | Device interface name to interface major version map based on most recent device introspection.                                                                                                    |
| `introspection_minor`         | `map<ascii, int>`                     | Device interface name to interface minor version map based on most recent device introspection.                                                                                                    |
| `old_introspection`           | `map<frozen<tuple<ascii, int>>, int>` | All previous device interfaces. This column is used to keep track of all interfaces that have been used and might still have some recorded data. The column maps interface (name, major) to minor. |
| `protocol_revision`           | `int`                                 | Spoken Astarte MQTT v1 protocol revision.                                                                                                                                                          |
| `first_registration`          | `timestamp`                           | First registration attempt timestamp.                                                                                                                                                              |
| `credentials_secret`          | `ascii`                               | The bcrypt hash of the credential secret, that the device uses to obtain new credentials.                                                                                                          |
| `inhibit_credentials_request` | `boolean`                             | Ban device credentials renewal, device will be able to connect to the transport up to  the credential expiry.                                                                                      |
| `cert_serial`                 | `ascii`                               | Device certificate serial used by the CA.                                                                                                                                                          |
| `cert_aki`                    | `ascii`                               | Device certificate Authority Key Identifier.                                                                                                                                                       |
| `first_credentials_request`   | `timestamp`                           | First credentials request timestamp.                                                                                                                                                               |
| `last_connection`             | `timestamp`                           | Most recent device connection event timestamp.                                                                                                                                                     |
| `last_disconnection`          | `timestamp`                           | Most recent device disconnection event timestamp.                                                                                                                                                  |
| `connected`                   | `boolean`                             | True if the device is connected, otherwise is false.                                                                                                                                               |
| `pending_empty_cache`         | `boolean`                             | Device is in an unclean state and an empty cache message is being waited.                                                                                                                          |
| `total_received_msgs`         | `bigint`                              | Count of received messages since the device registration.                                                                                                                                          |
| `total_received_bytes`        | `bigint`                              | Amount of received messages bytes since the device registration.                                                                                                                                   |
| `exchanged_msgs_by_interface` | `bigint`                              | Count of exchanged messages since the device registration.                                                                                                                                         |
| `exchanged_bytes_by_interface`| `bigint`                              | Amount of exchanged messages bytes since the device registration.                                                                                                                                  |
| `last_credentials_request_ip` | `inet`                                | Device IP address used during the last credential request.                                                                                                                                         |
| `last_seen_ip`                | `inet`                                | Most recent device IP address.                                                                                                                                                                     |
| `attributes`                  | `map<varchar, varchar>`               | Device attributes. It can contain arbitrary string key and values associated with the device.
| `groups`                      | `map<text, timeuuid>`                 | Groups which the device belongs to, the key is the group name, and the value is its insertion timeuuid, which is used as part of the key on grouped_devices table.                                                                                                                                                                               |

## Schema changes

This section describes the schema changes happening between different Astarte Versions.

They are divided between Astarte Keyspace (changes that affect the Astarte Keyspace), and Realm
Keyspaces (changes that affect all realm keyspaces).

Every change is followed by the CQL statement that produces the change.

### From v0.10 to v0.11

#### Astarte Keyspace v0.11 Changes

* Remove `astarte_schema` table

```sql
DROP TABLE astarte_schema;
```

* Remove `replication_factor` column from the `realms` table

```sql
ALTER TABLE realms
DROP replication_factor;
```

#### Realm Keyspaces v0.11 Changes

* Add `grouped_devices` table

```sql
CREATE TABLE <realm_name>.grouped_devices (
   group_name varchar,
   insertion_uuid timeuuid,
   device_id uuid,
   PRIMARY KEY ((group_name), insertion_uuid, device_id)
);
```

* Add `groups`, `exchanged_bytes_by_interface` and `exchanged_msgs_by_interface` columns to the
  `devices` table

```sql
ALTER TABLE <realm_name>.devices
ADD (groups map<text, timeuuid>,
    exchanged_bytes_by_interface map<frozen<tuple<ascii, int>>, bigint>,
    exchanged_msgs_by_interface map<frozen<tuple<ascii, int>>, bigint>);
```

* Add `database_retention_ttl` and `database_retention_policy` columns to the `endpoints` table

```sql
ALTER TABLE <realm_name>.endpoints
ADD (
  database_retention_ttl int,
  database_retention_policy int
);
```

### From v0.11 to v1.0.0-beta.1

#### Realm Keyspace v1.0.0-beta.1 Changes

* The `connected` field of the `devices` table is now saved with a TTL, so it automatically expires
  if it doesn't gets refreshed by the hearbeat sent by the broker. This behaviour was added to
  avoid stale connected devices if they disconnect while the broker is down.

* Add `metadata` column to the `devices` table

```sql
ALTER TABLE devices
ADD (
    metadata map<varchar, varchar>
);
```

### From v1.0-beta.1 to v1.0.0

#### Realm Keyspace v1.0.0 Changes

* Rename the `metadata` to `attributes` in the `devices` table

*Warning*: migrating data from the `metadata` column to the `attributes` one is possible but is out
of scope of this guide since this change happened between development releases. The procedure below
just removes and recreates the column *without migrating data*.

```sql
ALTER TABLE devices
DROP metadata;
```

```sql
ALTER TABLE devices
ADD (
    attributes map<varchar, varchar>
);
```
