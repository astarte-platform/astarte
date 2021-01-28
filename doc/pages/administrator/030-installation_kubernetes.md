# Installing Astarte Operator

The most simple and common installation procedure exploits the Astarte Operator's
[`Helm chart`](https://artifacthub.io/packages/helm/astarte/astarte-operator).

Helm is intended to be used as the operator's lifecycle management tool, thus make sure you are
ready with a working [`Helm installation`](https://helm.sh/docs/intro/install/).

## Installation

Installing the Operator is as simple as

```bash
helm repo add astarte https://helm.astarte-platform.org
helm repo update
helm install astarte-operator astarte/astarte-operator
```

This command will take care of installing all needed components for the Operator to run. This
includes all the RBAC roles, Custom Resource Definitions, and the Operator itself.

You can use the `--version` switch to specify a version to install. When not specified, the latest
stable version will be installed instead.

## Upgrading the Operator

The procedure for upgrading the Operator depends on the version of the Operator you want to
upgrade from.

### Upgrading the Operator (>= v1.0)

Astarte Operator's Helm chart is available since v1.0 and therefore the current upgrade procedure
applies only if you are dealing with at least v1.0.

To upgrade the Helm chart, use the dedicated `helm upgrade` command:

```bash
helm upgrade astarte-operator astarte/astarte-operator
```

The optional `--version` switch allows to specify the version to upgrade to - when not specified,
the latest version will be fetched and used.

By design, Astarte Operator's Helm charts cannot univocally be mapped to Operator's releases in a
one-to-one relationship. However each chart is tied to a specific Operator's version, which is user
configurable.

Therefore, upgrading a chart lead to an Operator's upgrade if and only if the Operator's tag
referenced by the chart is changed. You can check the Operator's tag binded to the chart simply
running:

```bash
helm show values astarte/astarte-operator
```

As usual, you can use the usual `--version` flag to point to a specific chart version.

Usually upgrading a chart is sufficient to upgrade the Operator to its last available stable
version. However in custom use cases you may want to deploy a specific version of the operator. To
do so, simply set the `tag` value while upgrading the chart:

```bash
helm upgrade astarte-operator astarte/astarte-operator --set tag=<the-required-tag>
```

### Upgrading the Operator (from v0.11 to v1.0)

The upgrade procedure from v0.11 to v1.0 requires some manual intervention as the deployment and
handling of the Operator's lifecylcle has changed: if v0.11 is entirely handled with `astartectl`,
v1.0 employs Helm charts.

To ensure a consistent upgrade procedure, the following steps are required:

+ Remove the Operator's Service Account, Cluster Roles and Cluster Role Bindings:
```bash
kubectl delete serviceaccounts -n kube-system astarte-operator
kubectl delete clusterroles.rbac.authorization.k8s.io astarte-operator
kubectl delete clusterrolebindings.rbac.authorization.k8s.io astarte-operator
```

+ Delete the Operator's deployment:
```bash
kubectl delete deployments.app -n kube-system astarte-operator
```

**DO NOT** delete Astarte's CRDs! This will lead to the deletion of the entire Astarte deployment
with a consequent data loss.

To restore the Operator's functionalities with v1.0, all you have to do is following the install
instructions, i.e.:
```bash
helm repo add astarte https://helm.astarte-platform.org
helm repo update
helm install astarte-operator astarte/astarte-operator --version 1.0-snapshot
```

Please note that version `1.0-snapshot` is a safe landing version to perform the upgrade. After
the successful installation, please upgrade to a more recent version following the instructions
outlined in the [previous section](#upgrading-the-operator-v1-0).

## Uninstalling the Operator

To uninstall the Operator, use the dedicated `helm uninstall` command.

```bash
helm uninstall astarte-operator
```

Uninstalling the Operator can be performed even if an Astarte instance is still active in the
cluster. The result of this operation consists in the deletion of RBACs and of the operator's
deployment itself.

*Note: CRDs are not affected by the uninstall procedure as, according to Helm's choices, forcing
their removal may lead to unwanted and (in some cases) catastrophic aftermaths. In case you want to
remove any of the CRDs, you will be responsible for their handling: be sure you know what you are
doing and act very carefully as you may end up with a broken cluster.*
