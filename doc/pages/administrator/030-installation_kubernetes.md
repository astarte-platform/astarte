# Installing Astarte Operator

The most simple and common installation procedure exploits the [Astarte Operator's Helm
chart](https://artifacthub.io/packages/helm/astarte/astarte-operator).

Helm is intended to be used as the operator's lifecycle management tool, thus make sure you are
ready with a working [Helm installation](https://helm.sh/docs/intro/install/).

Please, before starting with the Operator's install procedure make sure that any
[prerequisite](020-prerequisites.html) has been satisfied.

## Installation

Installing the Operator is as simple as

```bash
helm repo add astarte https://helm.astarte-platform.org
helm repo update
helm install astarte-operator astarte/astarte-operator -n kube-system
```

This command will take care of installing all needed components for the Operator to run. This
includes all the RBAC roles, Custom Resource Definitions, Webhooks, and the Operator itself.

You can use the `--version` switch to specify a version to install. When not specified, the latest
stable version will be installed instead.

## Upgrading the Operator

The procedure for upgrading the Operator depends on the version of the Operator you want to upgrade
from. Please refer to the [Upgrade Guide](000-upgrade_index.html) section that fits your needs.

## Uninstalling the Operator

To uninstall the Operator, use the dedicated `helm uninstall` command.

```bash
helm uninstall astarte-operator
```

Uninstalling the Operator can be performed even if an Astarte instance is still active in the
cluster. The result of this operation consists in the deletion of RBACs and of the Operator's
deployment itself.

*Note: CRDs are not affected by the uninstall procedure as, according to Helm's choices, forcing
their removal may lead to unwanted and (in some cases) catastrophic aftermaths. In case you want to
remove any of the CRDs, you will be responsible for their handling: be sure you know what you are
doing and act very carefully as you may end up with a broken cluster.*
