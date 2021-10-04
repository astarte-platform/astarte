# Upgrade v1.0

## Upgrade Astarte Operator

Astarte Operator's upgrade procedure is handled by Helm. However, according to the Helm policies,
upgrading the CRDs must be handled manually.

To upgrade the Astarte CRDs, the following environment variables will be employed:

- `ASTARTE_OP_TEMPLATE_DIR` is the target directory in which the chart templates will be generated,
- `ASTARTE_OP_RELEASE_NAME` is the name of the Astarte Operator deployment,
- `ASTARTE_OP_RELEASE_NAMESPACE` is the namespace in which the Astarte Operator resides.

Please, make sure that the values you set for both the Operator's name and namespace match the
naming you already adopted when installing the Operator. A wrong naming can lead to a malfunctioning
Astarte cluster.

For standard deployments the following variables should be ok. However, it is your responsibility
checking that the values you set are consistent with your setup:

```bash
export ASTARTE_OP_TEMPLATE_DIR=/tmp
export ASTARTE_OP_RELEASE_NAME=astarte-operator
export ASTARTE_OP_RELEASE_NAMESPACE=kube-system
```

Render the Helm templates with the following:
```bash
helm template $ASTARTE_OP_RELEASE_NAME astarte/astarte-operator \
    --namespace $ASTARTE_OP_RELEASE_NAMESPACE \
    --output-dir $ASTARTE_OP_TEMPLATE_DIR
```

After these step you will find the updated CRDs within
`$ASTARTE_OP_TEMPLATE_DIR/$ASTARTE_OP_RELEASE_NAME/templates/crds.yaml`. Update the CRDs in your
cluster by replacing the CRDs yaml file:
```bash
kubectl replace -f $ASTARTE_OP_TEMPLATE_DIR/$ASTARTE_OP_RELEASE_NAME/templates/crds.yaml
```

Finally, to upgrade the Operator use the dedicated `helm upgrade` command:
```bash
helm upgrade astarte-operator astarte/astarte-operator -n kube-system
```

The optional `--version` switch allows to specify the version to upgrade to - when not specified,
the latest version will be fetched and used. If you choose to upgrade to a specific version of the
chart by using the `--version` flag, please make sure to generate the updated CRDs template using
the same chart version.

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

## Upgrade Astarte

To upgrade your Astarte instance simply edit the Astarte resource in the cluster updating the
`version` field to the one you want to upgrate to.

Open the yaml file describing the Astarte resource with:
```bash
kubectl edit astarte -n astarte
```

Find the `version` field in the Astarte Spec section and change it according to your needs. Once the
yaml file will be saved, the Operator will take over ensuring the reconciliation of your Astarte
instance to the requested version.

### Caveats for Astarte Flow

Currently, although [Astarte Flow](https://docs.astarte-platform.org/flow/) is a component of
Astarte, it doesn't follow Astarte's release cycle. Therefore if you upgraded your Astarte instance
to v1.0.0, Astarte Operator will try to deploy `astarte/astarte_flow:1.0.0` which is currently not
existent.

All you have to do to overcome this temporary limitation is to edit your Astarte resource by
explicitly setting the Astarte Flow image you plan to use:
```yaml
spec:
  ...
  components:
    ...
    flow:
      image: <the-astarte-flow-image>
```

All the available Astarte Flow's tags can be found
[here](https://hub.docker.com/r/astarte/astarte_flow/tags?page=1&ordering=last_updated).
