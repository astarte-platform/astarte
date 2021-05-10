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

**WARNING** - *Understanding the consequences of the uninstall procedure is fundamental to avoid
catastrophic aftermaths. Please read carefully this section to understand how the uninstall
procedure may impact your Astarte instance.*

Be aware that the following statements hold:
1) the Astarte's CRDs are installed and handled by the Operator's Helm chart;
2) uninstalling the Operator causes the Astarte's CRDs to be marked for deletion;
3) the deletion of CRDs leads to the destruction of all the Kubernetes instances of the CRDs (i.e.
Astarte will be destroyed).

The [Advanced Operations
section](095-advanced-operations.html#handling-astarte-when-uninstalling-the-operator) outlines all
the relevant information to handle your Astarte instance when uninstalling the Operator, explains
how to recover your Astarte instance and highlights in a more exhaustive way what's happening under
the hood.

To uninstall the Operator, use the dedicated `helm uninstall` command. This operation is responsible
for the deletion of both RBACs and the Operator's deployment itself. Moreover, all the CRDs
installed by the Operator's Helm chart are marked for deletion.

```bash
helm uninstall astarte-operator -n kube-system
```

So, what should you expect after uninstalling the Operator?

After executing the `helm uninstall` command your Operator's deployment will be destroyed, along
with the `AstarteVoyagerIngress` and `Flow` CRDs and resources (when they exist). Both the Astarte
CRD and its instance will not be immediately destroyed as their deletion is allowed after the
Astarte finalizer is executed. Please refer to the [Advanced Operations
section](095-advanced-operations.html#handling-astarte-when-uninstalling-the-operator) to learn how
to handle your Astarte instance and how to restore its functionalities.
