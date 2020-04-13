# Upgrading the Cluster

Upgrading an Astarte Cluster is meant to be a completely managed operation, as the Operator encapsulates
all the needed logic for a clean Upgrade. Manual Upgrades are not supported and out of the scope of this
guide - if you're maintaining a non-operator installation, you will need to understand all the manual steps
for Upgrade for each Astarte component, which are explained in Release notes. However, the only supported
mean of Upgrade remains the Operator.

## Upgrading through astartectl

`astartectl` features an `astartectl cluster instances upgrade` command which can upgrade both `astartectl`
and non-`astartectl` Managed Installations alike. When using a Profile, though, the upgrade procedure will
also script any changes to the CR the profile carries over among versions (if needed), ensuring that the
process is smooth enough.

To upgrade, run

```bash
astartectl cluster instances upgrade <instance name>
```

You can optionally add an Astarte version as the second parameter - otherwise, `astartectl` will try to
upgrade to the latest stable release.

`astartectl` will interactively prompt you a number of questions depending on the operation, and will start
the upgrade procedure. Please note that depending on the upgrade, the operation might require a downtime.

## Upgrading by modifying the CR

If you do not want to use `astartectl`, you will need to upgrade by modifying the CR manually. Usually,
this boils down to bumping the `version` field in the spec - however, you should read all release notes
carefully to know if any other changes to the CR are required.

Once you apply the changes to the Resource, the Operator will take over and perform the Upgrade.
