# Installing Astarte Operator

Operator installation is usually intermediated by [`astartectl`](https://github.com/astarte-platform/astartectl),
through the `astartectl cluster` subcommand. `astartectl cluster` manages the entire lifecycle of Astarte within
a single Kubernetes Cluster, with regards of both the Operator and the Astarte instance(s) that will be deployed
in the Cluster.

## Installation

Installing the Operator is as simple as

```bash
astartectl cluster install-operator
```

This command will take care of installing all needed components for the Operator to run. This includes all the
RBAC roles, Custom Resource Definitions, and the Operator itself. The `--version` switch allows to specify a
version to install - when not specified, the latest version will be installed instead.

## Upgrading the Operator

To upgrade the Operator, use the dedicated `upgrade-operator` command.

```bash
astartectl cluster upgrade-operator
```

Just like the `install-operator` command, the `--version` switch allows to specify the version to upgrade to -
when not specified, the latest version will be fetched and used.

## Uninstalling the Operator

To uninstall the Operator, use the dedicated `uninstall-operator` command.

```bash
astartectl cluster uninstall-operator
```

This command will refuse to execute if any Astarte instances are active in the Cluster. Uninstalling the Operator
is possible only after all managed instances have been deleted too.
When uninstalling the Operator, all resources installed with `install-operator` will be erased completely.
