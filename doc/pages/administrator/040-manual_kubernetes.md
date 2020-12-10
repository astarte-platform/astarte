# Manual Operator Installation

In case you do not want to use `helm` to manage the Operator, this guide will run you through
all the steps needed to set up Astarte Kubernetes.

To come along with this guide, the following components are required:
+ [`operator-sdk`](https://sdk.operatorframework.io/docs/installation/install-operator-sdk/)
+ [`kustomize`](https://kubectl.docs.kubernetes.io/installation/kustomize/)

Please make sure that the version of `operator-sdk` matches or is compatible with the version
of the `operator-sdk` module in the Operator's `go.mod` file.

Moreover, please make sure that the cluster kubectl is pointing to is the one you want to target
with the installation.

*Note: Please be aware that this method is to be used only if you have very specific reasons why not
to use `helm`, for example: you're running a fork of the Operator, you're running the Operator
outside of the cluster, or you're on the very bleeding edge.
`helm` automates internally all of this guide and should be your main choice in production.*

## Clone the Operator Repository

First of all, you will need to clone the Operator repository, as this is where some of the needed
resources for the Operator are. Ensure you're cloning the right branch for the Operator Version
you'd like to install, in this case v1.0:

```bash
git clone https://github.com/astarte-platform/astarte-kubernetes-operator.git
cd astarte-kubernetes-operator
git checkout release-1.0
```

## Install RBACs and CRDs

The Operator requires a number of RBAC roles to run, and will also require Astarte CRDs to be
installed.

To install all the required components, simply run:
```bash
make install
```

## Running the Operator inside the Cluster

Running the Operator inside the cluster is as simple as executing the following:
```bash
make deploy
```

Actually, the above command does more than just deploying the Operator, as it also install RBACs,
CRDs. The deployment therefore can be performed in just one command.

To check if the deployment is successful:
```bash
kubectl get deployment -n kube-system astarte-operator
```

## Running the Operator outside the Cluster

*Note: Running the operator outside the cluster is not advised in production. Usually, you need such
a deployment if you plan on developing the Operator itself. However, this scenario is tested in the
e2e tests, and as such provides the very same features of the in-cluster Deployment, which remains
the go-to scenario for production.*

From the root directory of your clone, run:

```bash
make run
```

This will bring up the Operator and connect it to your current Kubernetes context.

### Caveats

When running the Operator locally, you're bound to a single namespace, and to all limitations of
`operator-sdk run`. This is out of the scope of this guide, and you should be confident with
[`operator-sdk`'s User
Guide](https://github.com/operator-framework/operator-sdk/blob/master/doc/user-guide.md) if you plan
on running the Operator outside the Cluster.
