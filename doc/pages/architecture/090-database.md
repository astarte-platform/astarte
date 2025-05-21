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

`astarte` keyspace and tables are created by Housekeeping on the first run with the following [CQL](https://docs.datastax.com/en/cql/3.3/index.html) statements:

```sql
CREATE KEYSPACE astarte
  WITH replication = {'class': 'SimpleStrategy', 'replication_factor': <replication factor>}  AND
    durable_writes = true;
```

The table containing all existing realms with their relative limits:

```sql
CREATE TABLE astarte.realms (
  realm_name varchar,
  device_registration_limit bigint,

  PRIMARY KEY (realm_name)
);
```

A table acting as a generic key-value store for multiple purposes:

```sql
CREATE TABLE astarte.kv_store (
    group varchar,
    key varchar,
    value blob,
    PRIMARY KEY (group, key)
)
```

For instance, the key-value store is used to persist the current Astarte schema version, used to manage database migrations:

```sql
INSERT INTO astarte.kv_store
    (group, key, value)
    VALUES ('astarte', 'schema_version', bigintAsBlob(<latest Astarte schema version>));
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

Some data storage tables might be created when required, whereas all other tables are created when a keyspace is created, using the following statements.

The realm's keyspace that segregates all tables and data relative to a specific realm and specifies how data should be replicated and managed:

```sql
CREATE KEYSPACE <realm name>
  WITH replication = {'class': 'SimpleStrategy', 'replication_factor': :replication_factor} AND
    durable_writes = true;
```

Replication can also be configured with a NetworkTopologyStrategy class, especially for production environments.

A table acting as a generic key-value store is also created for each realm:

```sql
CREATE TABLE <realm name>.kv_store (
  group varchar,
  key varchar,
  value blob,

  PRIMARY KEY ((group), key)
);
```

The `names` table is used to create optional names for resources that would be otherwise identified only by their UUID.
Currently, only device objects are optionally given a name.

```sql
CREATE TABLE <realm name>.names (
  object_name varchar,
  object_type int,
  object_uuid uuid,

  PRIMARY KEY ((object_name), object_type)
);
```

The `devices` table is used to populate a registry of the existing devices in the realm:

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

  groups map<varchar, timeuuid>,

  PRIMARY KEY (device_id)
);
```

Each device has a `groups` field indicating which groups it belongs to.
The `grouped_devices` table is needed to perform the reverse query and know which devices belong to certain group.

```sql
CREATE TABLE <realm name>.grouped_devices (
  group_name varchar,
  insertion_uuid timeuuid,
  device_id uuid,
  PRIMARY KEY ((group_name), insertion_uuid, device_id)
);
```

The `endpoints` table is dedicated to store information about the endpoints of the existing Astarte interfaces, where each endpoint is accompanied by information about how device data for the endpoint should be handled.
Each endpoint references an Astarte interface installed in the realm.

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

The `interfaces` table declares which interfaces are installed in the realm.

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

```sql

CREATE TABLE <realm name>.individual_datastreams (
    device_id uuid,
    interface_id uuid,
    endpoint_id uuid,
    path varchar,
    value_timestamp timestamp,
    reception_timestamp timestamp,
    reception_timestamp_submillis smallint,
    binaryblob_value blob,
    binaryblobarray_value list<blob>,
    boolean_value boolean,
    booleanarray_value list<boolean>,
    datetime_value timestamp,
    datetimearray_value list<timestamp>,
    double_value double,
    doublearray_value list<double>,
    integer_value int,
    integerarray_value list<int>,
    longinteger_value bigint,
    longintegerarray_value list<bigint>,
    string_value varchar,
    stringarray_value list<varchar>,
    PRIMARY KEY ((device_id, interface_id, endpoint_id, path), value_timestamp, reception_timestamp, reception_timestamp_submillis)
) 
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
CREATE TABLE <realm name>.deletion_in_progress (
  device_id uuid,
  vmq_ack boolean,
  dup_start_ack boolean,
  dup_end_ack boolean,
  PRIMARY KEY (device_id)
);
```

The following table is generated upon datastream interface creation for keeping all data sent to Astarte through the interface.

The table name is derived from lower case interface name where `.` and `-` have been replaced by `_` and `""` (empty string), then the major version is appended with a `_v` prefix. 
For example, com.Astarte.TestInterface version 1 becomes  `com_astarte_testinterface_v1`.

If, after all the required transformations, the resulting name is too long (>45 chars), it will be encoded and truncated.

```sql
CREATE TABLE <interpolated interface name>_v<major_version> (
    device_id uuid,
    path varchar,
    reception_timestamp timestamp,
    reception_timestamp_submillis smallint,
    v_<property_mapping> <property_type>
    v_<property_mapping> <property_type>
    ...
    PRIMARY KEY ((device_id, path), reception_timestamp, reception_timestamp_submillis)
) 

```

Then some initial values are inserted into the following tables to initialize the realm.

The realm's public key:

```sql
INSERT INTO <realm name>.kv_store (group, key, value)
    VALUES ('auth', 'jwt_public_key_pem', varcharAsBlob(<public key PEM>));
```

The version of the realm schema, used for database migrations:

```sql
INSERT INTO <realm name>.kv_store
  (group, key, value)
  VALUES ('astarte', 'schema_version', bigintAsBlob(<latest realm schema version>));
```

The maximum storage retention for datastreams:

```sql
INSERT INTO <realm name>.kv_store (group, key, value)
  VALUES ('realm_config', 'datastream_maximum_storage_retention', intAsBlob(<max retention>));
```

Finally, the realm is created in the realms table with a specific device registration limit, if any:

```sql
INSERT INTO astarte.realms (realm_name, device_registration_limit)
  VALUES (<realm name>, <device registration limit>);
```

## Tables

### Devices

The `devices` table stores the list of all the devices for a certain realm and all their metadata, including the introspection, the device status and credentials information.

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
| `inhibit_credentials_request` | `boolean`                             | Ban device credentials renewal, device will be able to connect to the transport up to the credential expiry.                                                                                      |
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
| `groups`                      | `map<varchar, timeuuid>`              | Groups which the device belongs to, the key is the group name, and the value is its insertion timeuuid, which is used as part of the key on grouped_devices table.     

### Endpoints

The `endpoints` table stores the list of all endpoints of all interfaces for realm, with all the data needed to define an endpoint, such as retention, realiability, value type and so on.

| Column Name                   | Column Type                           | Description                                                                                                                                                                                        |
|-------------------------------|---------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `interface_id`                | `uuid`                                | Interface unique 128 bits ID.                                                                                                                                                                      |
| `endpoint_id`                 | `uuid`                                | Endpoint unique 128 bits ID.                                                                                                                                                                       |
| `interface_name`              | `ascii`                               | Human-readable name for interface.                                                                                                                                                                 |
| `interface_major_version`     | `int`                                 | Interface major version related to the endpoint.                                                                                                                                                   |
| `interface_minor_version`     | `int`                                 | Interface minor version related to the endpoint.                                                                                                                                                   |
| `interface_type`              | `int`                                 | Interface type identifier related to the endpoint.                                                                                                                                                 |
| `endpoint`                    | `ascii`                               | Human-readable endpoint string.                                                                                                                                                                    |
| `value_type`                  | `int`                                 | Value type identifier related to the endpoint.                                                                                                                                                     |
| `reliability`                 | `int`                                 | Reliability identifier related to the endpoint.                                                                                                                                                    |
| `retention`                   | `int`                                 | Retention identifier related to the endpoint.                                                                                                                                                      |
| `expiry`                      | `int`                                 | Expiry identifier related to the endpoint.                                                                                                                                                         |
| `database_retention_ttl`      | `int`                                 | Milliseconds before data deletion.                                                                                                                                                                 |
| `database_retention_policy`   | `int`                                 | Database_retention_policy identifier related to the endpoint.                                                                                                                                      |
| `allow_unset`                 | `boolean`                             | Enable or disable possibility of setting value to null.                                                                                                                                            |
| `explicit_timestamp`          | `boolean`                             | Set or unset explicit timestamp.                                                                                                                                                                   |
| `description`                 | `varchar`                             | Description of endpoint.                                                                                                                                                                           |          
| `doc`                         | `varchar`                             | Documentation for endpoint.                                                                                                                                                                       | 



### Interfaces

The `interfaces` table stores the list of all interfaces for realm, with all the data needed to define an endpoint, such as retention, realiability, value type and so on.

| Column Name                   | Column Type                           | Description                                                                                                                                                                                        |
|-------------------------------|---------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `interface_id`                | `uuid`                                | Interface unique 128 bits ID.                                                                                                                                                                      |
| `name`                        | `ascii`                               | Human-readable name for interface.                                                                                                                                                                 |
| `major_version`               | `int`                                 | Interface major version related to the endpoint.                                                                                                                                                   |
| `minor_version`               | `int`                                 | Interface minor version related to the endpoint.                                                                                                                                                   |
| `storage_type`                | `int`                                 | Storage type identifier related to the endpoint.                                                                                                                                                   |
| `storage`                     | `ascii`                               | Interface storage.                                                                                                                                                                                 |
| `type`                        | `int`                                 | Identifies the type of this Interface. Currently two types are supported: datastream and properties.                                                                                               |
| `ownership`                   | `int`                                 | Identifies the quality of the interface. Interfaces are meant to be unidirectional, and this property defines who's sending or receiving data.                                                     |
| `aggregation`                 | `int`                                 | Identifies the aggregation of the mappings of the interface.                                                                                                                                       |
| `automaton_transitions`       | `blob`                                | Automaton internal field.                                                                                                                                                                          |
| `automaton_accepting_states`  | `blob`                                | Automaton internal field.                                                                                                                                                                          |
| `description`                 | `varchar`                             | Description of interface.                                                                                                                                                                          |
| `doc`                         | `varchar`                             | Documentation of interface.                                                                                                                                                                        |


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
ADD (groups map<varchar, timeuuid>,
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
just creates the new column and then deletes the old one *without migrating data*. You're free to
implement a migration procedure between the two steps.

```sql
ALTER TABLE devices
ADD (
    attributes map<varchar, varchar>
);
```

```sql
ALTER TABLE devices
DROP metadata;
```
