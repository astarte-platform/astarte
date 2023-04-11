# Advanced operations

This section provides guidance on some delicate operations that must be performed manually as they
could potentially result in data loss or other types of irrecoverable damage.

*Always be careful while performing these operations!*

## Manual deletion of interfaces

Right now, Astarte only allows deleting draft interfaces, i.e. interfaces with major version `0` and
not used by any device.

If you want to delete an interface that has already published data, you must proceed manually with
the steps described below. This guide assumes the aim of the operation is deleting the
`org.astarte-platform.genericsensors.Values` interface in the `test` realm.

The guide requires that [`cqlsh`](https://cassandra.apache.org/doc/latest/tools/cqlsh.html) is
connected to the Cassandra/ScyllaDB instance that your Astarte instance is using.

### Switch to the target keyspace

The keyspace has the same name of the realm, in this case it is `test`:

```
cqlsh> use test;
```

### Find out the interface id

```
cqlsh:test> SELECT interface_id FROM interfaces
  WHERE name='org.astarte-platform.genericsensors.Values'
  AND major_version = 1;
```

`cqlsh` will reply with the interface id:

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

*Keep in mind that after this step, all existing devices that attempt to publish on this interface
will be disconnected as soon as they try to do so.*

### Delete interface data

The interface data is stored in a different place depending on the interface type (`datastream` or
`properties`) and aggregation.

- Individual datastream interfaces store their data in the `individual_datastreams` table.
- Individual properties interfaces store their data in the `individual_properties` table.
- Object datastream interfaces store their data in a dedicated table which is created starting from
  the interface (e.g. an interface called `com.test.Sensors` with major version `1` creates a
  `com_test_sensors_v1` table in the realm keyspace).

To delete data from object datastreams, a simple `DROP` of the table where the data is stored is
needed.

Deleting data from individual interfaces requires more steps. In this example the interface is an
individual datastream, but the procedure for individual properties is the same, but concerns the
`individual_properties` table instead.

To delete the interface data, first all relevant primary keys must be found:

```
cqlsh:test> SELECT DISTINCT device_id, interface_id, endpoint_id, path FROM individual_datastreams
  WHERE interface_id=c238b244-b90f-4c6d-f276-25768bf6abac ALLOW FILTERING;
```

This will return a set of primary keys of data belonging to that interface:

```
 device_id                            | interface_id                         | endpoint_id                          | path
--------------------------------------|--------------------------------------|--------------------------------------|-------------
 41c1c072-d416-4686-ba23-673fe4ad926f | c238b244-b90f-4c6d-f276-25768bf6abac | 33751412-3e77-ad1f-ad57-280cc9fad581 | /test/value
 81c60277-4645-441f-a49b-66a71ce54b83 | c238b244-b90f-4c6d-f276-25768bf6abac | 33751412-3e77-ad1f-ad57-280cc9fad581 | /foo/value
 ...
```

After that, all data belonging to those primary keys must be deleted:

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

If this guide is being used so as to remove a draft interface (i.e. with major version `0`) that
cannot be deleted since it has data on it, an additional step is required for a complete cleanup.

The information about which devices are using draft interfaces is kept in the `kv_store` table. You
can inspect the groups with:

```
cqlsh:test> SELECT group FROM kv_store;
```

The group that has to be deleted may be easily identified by inspecting the returned `group`s, since
it is the one with its name derived from the interface name. For example, if the purpose of the
operation is removing all data from the `org.astarte-platform.genericevents.DeviceEvents v0.1`
interface, the corresponding `group` in `kv_store` will be
`devices-by-interface-org.astarte-platform.genericevents.DeviceEvents-v0`.

As the target group is identified, just remove all its entries with:

```
cqlsh:test> DELETE FROM kv_store WHERE group='devices-by-interface-org.astarte-platform.genericevents.DeviceEvents-v0';
```

### Conclusions

After performing all the steps above, the interface will be completely removed from Astarte. You can
then proceed to install a new interface with the same name and major version without any conflict.

*Remember to remove the interface also on the device side, otherwise devices will keep getting
disconnected if they try to publish on the deleted interface.*

---

## Manual deletion of a device

Currently, the Astarte API allows for the unregistration and the inhibition of a specific device. If
you want to entirely delete a device from your realm along with its data, a manual procedure is
required.

This section assumes:
- that `cqlsh` is connected to the Cassandra/ScyllaDB instance that your Astarte is using;
- that `astartectl` is installed on your machine.

***Please keep in mind that this is a destructive procedure. Before moving on, ensure you saved your
device ID or you might end up with dangling data and possibly a damaged Astarte deployment.***

### Retrieve the device uuid

To interact with the device and its data, the device uuid must be retrieved. Assuming that the
id of the device to be deleted is `k3oPTXaGGGGGGGGGGGGGGG`, its uuid can be obtained with the
following:

```bash
$ astartectl utils device-id to-uuid k3oPTXaGGGGGGGGGGGGGGG
937a0f4d-7686-1861-8618-618618618618
```

Please, make sure not to lose the device uuid as it will be employed in all the following steps of
this section.

### Switch to the target keyspace

The keyspace takes its name from the realm, in this case it is `test`.

```
cqlsh> use test;
```

### Delete device data on a specific interface

Depending on the interface type and aggregation, data published by the device is stored into
different tables:

- data published over an individual datastream interface are available within the
  `individual_datastreams` table;
- data published over an individual property interface are available within the
  `individual_properties` table;
- data published over an object datastream interfaces are stored in a dedicated table named after
  the interface name: e.g. an interface called `com.test.Sensors` with major version 1 creates a
  `com_test_sensors_v1` table in the realm keyspace.

#### Delete device data from an `individual_datastreams` interface

The first step consists in finding all the relevant primary keys for the device. To do so, simply
run:

```
cqlsh:test> SELECT DISTINCT device_id, interface_id, endpoint_id, path FROM individual_datastreams
  WHERE device_id=937a0f4d-7686-1861-8618-618618618618 ALLOW FILTERING;
```

The output will show a set of primary keys of data belonging to your device:
```
 device_id                            | interface_id                         | endpoint_id                          | path
--------------------------------------|--------------------------------------|--------------------------------------|-------------
 937a0f4d-7686-1861-8618-618618618618 | c238b244-b90f-4c6d-f276-25768bf6abac | 33751412-3e77-ad1f-ad57-280cc9fad581 | /test/value
 937a0f4d-7686-1861-8618-618618618618 | 1e6fb841-9ee3-0e60-72ed-1f55b334b832 | 33751412-3e77-ad1f-ad57-280cc9fad581 | /foo/value
 ...
```

It is now time to perform the actual data deletion: to do so, repeat the following instruction
iterating over every combination of primary keys as obtained from the output of the previous
command:
```
cqlsh:test> DELETE FROM individual_datastreams
  WHERE device_id=937a0f4d-7686-1861-8618-618618618618
  AND interface_id=c238b244-b90f-4c6d-f276-25768bf6abac
  AND endpoint_id=33751412-3e77-ad1f-ad57-280cc9fad581
  AND path='/test/value';
```

#### Delete device data from an `individual_properties` interface

The first step consists in retrieving the primary keys for the device. Just run:

```
cqlsh:test> SELECT DISTINCT device_id, interface_id FROM individual_properties
  WHERE device_id = 937a0f4d-7686-1861-8618-618618618618 ALLOW FILTERING;
```

The output will be similar to the following one:
```
 device_id                            | interface_id
--------------------------------------+--------------------------------------
 937a0f4d-7686-1861-8618-618618618618 | c238b244-b90f-4c6d-f276-25768bf6abac
 937a0f4d-7686-1861-8618-618618618618 | 8ed086db-0bcc-5a9f-2fc2-ddf49c35e87d
 937a0f4d-7686-1861-8618-618618618618 | c61879ce-c60c-adaf-c6b4-d04b1e1b14c4
```

To perform the actual data deletion, run the following query for each pair of `device_id` and
`interface_id` obtained from the previous query:
```
cqlsh:test> DELETE FROM individual_properties
  WHERE device_id = 937a0f4d-7686-1861-8618-618618618618
  AND interface_id = c238b244-b90f-4c6d-f276-25768bf6abac;
```

#### Delete device data for object datastreams

The first step consists in retrieving the primary keys for the device. For this particular example
the sample interface named `com.test.Sensors` with major version `v1` is employed. Please note that
the upcoming steps must be repeated for each object datastream interface installed in your realm.

```
cqlsh:test> SELECT DISTINCT device_id, path FROM com_test_sensors_v1 WHERE
  device_id=937a0f4d-7686-1861-8618-618618618618 ALLOW FILTERING;
```

The output will show something like:
```
 device_id                            | path
--------------------------------------+------
 937a0f4d-7686-1861-8618-618618618618 | /foo
 ...
```

It is now time to perform the actual data deletion:

```
cqlsh:test> DELETE FROM com_test_sensors_v1
  WHERE device_id=937a0f4d-7686-1861-8618-618618618618
  AND path='/foo';
```

### Delete device aliases

If your device has one or more aliases you will find them in the `names` table.

First, you have to find the primary key for the device:

```
cqlsh:test> SELECT object_name FROM names
  WHERE object_uuid=937a0f4d-7686-1861-8618-618618618618 ALLOW FILTERING;
```

If your device has any aliases, the output will show
```
 object_name
----------------
 my-device-alias
 ...
```

Thus, you can delete the alias simply executing:
```
cqlsh:test> DELETE FROM names WHERE object_name='my-device-alias';
```

### Delete the device from groups

To delete the device from a device group let's find the needed keys:
```
SELECT group_name, insertion_uuid, device_id
  FROM grouped_devices
  WHERE device_id=937a0f4d-7686-1861-8618-618618618618
  ALLOW FILTERING;
```

If the device is contained in one or more groups, the output will be:

```
 group_name | insertion_uuid                       | device_id
------------+--------------------------------------+--------------------------------------
   my-group | c1a0dade-43bc-11ec-95be-41f7663270b3 | 937a0f4d-7686-1861-8618-618618618618
   ...
```

The actual deletion can be performed with:
```
cqlsh:test> DELETE FROM grouped_devices
  WHERE group_name='my-group'
  AND insertion_uuid=c1a0dade-43bc-11ec-95be-41f7663270b3
  AND device_id=937a0f4d-7686-1861-8618-618618618618;
```

### Delete entries from `kv_store`

If your device is publishing over one or more interfaces with version `v0`, you will need to handle
also the `kv_store` table.

Retrieve all the entries that must be handled:

```
cqlsh:test> SELECT group, key FROM kv_store WHERE key='k3oPTXaGGGGGGGGGGGGGGG' ALLOW FILTERING;
```

The output of the query will show something similar to

```
 group                                                   | key
---------------------------------------------------------+------------------------
             devices-by-interface-com.test.Sensor-v0 | k3oPTXaGGGGGGGGGGGGGGG
   devices-with-data-on-interface-com.test.Sensor-v0 | k3oPTXaGGGGGGGGGGGGGGG
   ...
```

To remove the entries, simply execute the following queries to remove the proper rows from the
table. Please, make sure to remove all the entries referencing your device ID.

```
cqlsh:test> DELETE FROM kv_store
  WHERE group='devices-by-interface-com.test.Sensor-v0'
  AND key='k3oPTXaGGGGGGGGGGGGGGG';

cqlsh:test> DELETE FROM kv_store
  WHERE group='devices-with-data-on-interface-com.test.Sensor-v0'
  AND key='k3oPTXaGGGGGGGGGGGGGGG';
```

### Eventually delete your device

Deleting your device from the devices table is as simple as

```
cqlsh:test> DELETE FROM devices WHERE device_id=937a0f4d-7686-1861-8618-618618618618;
```

### Conclusions

If you managed to remove all the device-related entries as described in the previous sections, then
your device and its data have been properly deleted from Astarte.

Before trying to reconnect your device you **must** make sure that the SSL certificate and all
the credentials onboard your device are deleted. This is crucial for ensuring that new data
published by the device can be properly ingested and processed by Astarte.
