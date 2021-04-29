# Advanced operations

This section provides guides to perform some operations that have to be perfomed manually since they
could result in data loss or other type of irrecoverable damage. *Always be careful while performing
these operations*

## Manual deletion of interfaces

Right now, Astarte only allows deleting draft interfaces, i.e. interfaces with major version `0` and
not used by any device.

If you want to delete an interface that already has published data, you must proceed manually with
the steps described below. In this guide we're going to assume that you're trying to delete the
`org.astarte-platform.genericsensors.Values` interface in the `test` realm.

The guide requires that you have [`cqlsh`](https://cassandra.apache.org/doc/latest/tools/cqlsh.html)
connected to the Cassandra/ScyllaDB instance that your Astarte instance is using.

### Switch to the target keyspace

The keyspace has the same name of the realm, in our case it's `test`

```
cqlsh> use test;
```

### Find out the interface id

```
cqlsh:test> SELECT interface_id FROM interfaces
  WHERE name='org.astarte-platform.genericsensors.Values'
  AND major_version = 1;
```

`cqlsh` will reply with the interface id

```
 interface_id
--------------------------------------
 c238b244-b90f-4c6d-f276-25768bf6abac
```

### Delete the interface

*WARNING: This is a destructive step that will erase the correlation between the Interface name and
internal ID. Before proceeding, ensure you saved the interface ID, or you will end up with dangling
data. Further steps in this guide will require the interface ID.*

To delete the interface,

```
cqlsh:test> DELETE FROM interfaces
  WHERE name='org.astarte-platform.genericsensors.Values'
  AND major_version = 1;
```

*Keep in mind that after this step, all existing devices that try to publish on this interface will
be disconnected as soon as they try to do so.*

### Delete interface data

The interface data is stored in a different place depending on the interface type (`datastream` or
`properties`) and aggregation.

- Individual datastream interfaces store their data in the `individual_datastreams` table.
- Individual properties interfaces store their data in the `individual_properties` table.
- Object datastream interfaces store their data in a dedicated table which is created starting from
  the interface (e.g. an interface called `com.test.Sensors` with major version `1` creates a
  `com_test_sensors_v1` table in the realm keyspace).

To delete data from object datastreams, you just need to `DROP` the table where the data is stored.

Deleting data from individual interfaces requires more steps. In this example the interface is an
individual datastream, but the procedure for individual properties is the same, but using the
`individual_properties` table instead.

To delete the interface data, first you have to find all the relevant primary keys

```
cqlsh:test> SELECT DISTINCT device_id, interface_id, endpoint_id, path FROM individual_datastreams
  WHERE interface_id=c238b244-b90f-4c6d-f276-25768bf6abac ALLOW FILTERING;
```

This will return a set of primary keys of data belonging to that interface

```
 device_id                            | interface_id                         | endpoint_id                          | path
--------------------------------------|--------------------------------------|--------------------------------------|-------------
 41c1c072-d416-4686-ba23-673fe4ad926f | c238b244-b90f-4c6d-f276-25768bf6abac | 33751412-3e77-ad1f-ad57-280cc9fad581 | /test/value
 81c60277-4645-441f-a49b-66a71ce54b83 | c238b244-b90f-4c6d-f276-25768bf6abac | 33751412-3e77-ad1f-ad57-280cc9fad581 | /foo/value
 ...
```

After that, you have to delete all the data belonging to those primary keys

```
cqlsh:test> DELETE FROM individual_datastreams
  WHERE device_id=41c1c072-d416-4686-ba23-673fe4ad926f
  AND interface_id=c238b244-b90f-4c6d-f276-25768bf6abac
  AND endpoint_id=33751412-3e77-ad1f-ad57-280cc9fad581
  AND path='/test/value';

cqlsh:test> DELETE FROM individual_datastreams
  WHERE device_id=81c60277-4645-441f-a49b-66a71ce54b83
  AND interface_id=c238b244-b90f-4c6d-f276-25768bf6abac
  AND endpoint_id=33751412-3e77-ad1f-ad57-280cc9fad581
  AND path='/foo/value';
...
```

### `devices-by-interface` cleanup

If you're using this guide to remove an draft interface (i.e. with major version `0`) that can't be
deleted since it has data on it, an additional step is required for a complete cleanup.

The information about which devices are using draft interfaces is kept in the `kv_store` table. You
can inspect the groups with

```
cqlsh:test> SELECT group FROM kv_store;
```

Inspecting the returned `group`s, you can easily identify which group has to be deleted, since it's
the one with its name derived from the interface name. For example, if you're trying to remove all
data from the `org.astarte-platform.genericevents.DeviceEvents v0.1` interface, the corresponding
`group` in `kv_store` will be
`devices-by-interface-org.astarte-platform.genericevents.DeviceEvents-v0`.

After you identify the group, just remove all its entries with

```
cqlsh:test> DELETE FROM kv_store WHERE group='devices-by-interface-org.astarte-platform.genericevents.DeviceEvents-v0';
```

### Conclusion

After you end performing all the steps above, the interface will be completely removed from Astarte.
You can then proceed to install a new interface with the same name and major version without any
conflict. *Remember to remove the interface also on the device side, otherwise devices will keep
getting disconnected if they try to publish on the deleted interface.*
