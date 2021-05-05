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

After you retrieve the interface id, you can delete the interface 

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

## Backup your Astarte resources

Backing up your Astarte resources is crucial in all those cases in which your Astarte instance has
to be restored after an unforeseen event (e.g. accidental deletion of resources, deletion of the
Operator - as it will be discussed later on - etc.).

A full recovery of your Astarte instance along with all the persisted data is possible **if and only
if** your Cassandra/Scylla instance is deployed independently from Astarte, i.e. it must be deployed
outside of the Astarte CR scope. If this condition is met, all the data are persisted into the
database even when Astarte is deleted from your cluster.

To restore your Astarte instance all you have to do is saving the following resources:
+ Astarte CR;
+ AstarteVoyagerIngress CR;
+ CA certificate and key;

and, assuming that your Astarte's name is `astarte` and that it is deployed within the `astarte`
namespace, it can be done simply executing the following commands:
```bash
kubectl get astarte -n astarte -o yaml > astarte-backup.yaml
kubectl get avi -n astarte -o yaml > avi-backup.yaml
kubectl get astarte-devices-ca -n astarte -o yaml > astarte-devices-ca-backup.yaml
```

## Restore your backed up Astarte instance

To restore your Astarte instance simply apply the resources you saved as described
[here](#backup-your-astarte-resources). Please, be aware that the order of the operations matters.

```bash
kubectl apply -f astarte-devices-ca-backup.yaml
kubectl apply -f astarte-backup.yaml
```

And when your Astarte resource is ready:

```bash
kubectl apply -f avi-backup.yaml
```

At the end of this step, your cluster is restored. Please, notice that the external IP of the
ingress services might have changed. Take action to ensure that the changes of the IP are reflected
anywhere appropriate in your deployment.

## Handling Astarte when uninstalling the Operator

Installing the Astarte Operator is as simple as installing its Helm chart. Even if the
install and upgrade procedures are very simple and straightforward, the design choices behind the
development of the Operator must be taken into account to avoid undesired effects while handling the
Operator's lifecycle.

The installation of the Operator's Helm chart is responsible for the creation of RBACs, the creation
of the Operator's deployment and the installation of Astarte CRDs. The fact that all the CRDs
installed with the Helm chart are templated has some important consequences: if on one hand this
characteristic ensures great flexibility in configuring your Astarte instance, on the other hand it
entails the possibility of deleting the CRDs by simply uninstalling the Operator.

The following sections will highlight what happens under the hood while uninstalling the Operator
and show the suggested path to restore your Astarte instance after the removal of the Operator.

Please, read carefully the following sections before taking any actions on your cluster and be aware
that improper operations may have catastrophic effects on your Astarte instance.

### What happens when uninstalling the Operator

The Operator's installation procedure marks all the Astarte CRDs as owned by the Operator itself.
Therefore, when the Operator is uninstalled all the CRDs are seen as orphaned and the Kubernetes
controller automatically set them as ready to be deleted. Thus, when the Operator is uninstalled you
end up with the following situation:
- Flow and AstarteVoyagerIngress CRDs are deleted, along with the custom resources depending on
  said CRDs;
- Astarte CRD is marked for deletion, but its removal is postponed until the moment in which the
  Astarte finalizer is executed.

### Backup your resources

Even if removing the Operator can potentially destroy your Astarte instance, there is a way to
restore it avoiding any data loss. Please, refer to [this dedicated
section](#backup-your-astarte-resources) to understand how to backup your resources.

### Uninstall the Operator

Once the backup of your resources is completed you can `helm uninstall` the Operator as explained
[here](030-installation_kubernetes.html#uninstalling-the-operator).

Once the Operator is deleted your Astarte instance will be marked for deletion. You can see it
simply checking the `Deletion timestamp` field in the output of:
```bash
kubectl describe astarte -n astarte
```

### Reinstalling the Operator

Reinstalling the Operator is crucial to have a correct management of your Astarte instance. The
installation is handled simply with an `helm install` command as explained
[here](030-installation_kubernetes.html#installation).

When the first reconciliation loop is executed, the Operator becomes aware that the Astarte resource
is marked for deletion, so it executes the Astarte finalizer and eventually destroys the Astarte's
CRD and its resources.

Even if it might look like the status of the cluster is compromised, a simple command reestablishes
the order:
```bash
helm upgrade --install astarte-operator astarte/astarte-operator --devel -n kube-system
```
This command simply upgrades the Operator and, as a result, installs the missing CRDs. Now it's time
to restore the Astarte resources.

### Apply backed up resources

To restore your Astarte instance simply follow the instructions outlined
[here](#restore-your-backed-up-astarte-instance).

### Conclusion

The procedure presented in the current section allows to handle the deletion of the Operator from
your cluster without losing any of the Astarte's data. Currently some manual intervention is
required to ensure that the integrity of your instance is not compromised by the uninstall
procedure.
