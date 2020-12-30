# Prerequisites

As much as Astarte's Operator is capable of creating a completely self-contained installation,
there's a number of prerequisites to be fulfilled depending on the use case.

## On your machine

In your local machine, you'll need two main tools:
[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and
[astartectl](https://github.com/astarte-platform/astartectl).

Ensure you have a `kubectl` version matching your target Kubernetes cluster version, and a recent `astartectl`
version.

## Voyager

Astarte currently features only one Managed Ingress, based on [Voyager](https://github.com/appscode/voyager).
Voyager provides routing, SSL termination and more, and as of today is the preferred/advised way to run Astarte
in production.

Astarte Operator is capable of interacting with Voyager through its dedicated `AstarteVoyagerIngress` resource,
as long as the Voyager Operator is installed. Installing Voyager Operator is outside the scope of this guide, and
you should refer to [Voyager's documentation](https://appscode.com/products/voyager/latest/setup/install/).

You don't need to create Voyager ingresses yourself - just the Operator itself is enough.

## cert-manager

Astarte requires [`cert-manager`](https://cert-manager.io/) to be installed in the cluster in its default
configuration (installed in namespace `cert-manager` as `cert-manager`). If you are using `cert-manager` in your
cluster already you don't need to take any action - otherwise, you will need to install it.

Astarte is actively tested with `cert-manager` 1.1, but should work with any 1.0+ releases of `cert-manager`.

[`cert-manager` documentation](https://cert-manager.io/docs/installation/) details all needed steps to have
a working instance on your cluster - however, in case you won't be using `cert-manager` for other components beyond
Astarte or, in general, if you don't have very specific requirements, it is advised to install it through its Helm
chart. To do so, run the following commands:

```bash
$ helm repo add jetstack https://charts.jetstack.io
$ helm repo update
$ kubectl create namespace cert-manager
$ helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.1.0 \
  --set installCRDs=true
```

This will install `cert-manager` 1.1.0 and its CRDs in the cluster.

## External Cassandra

In production deployments, it is strongly advised to have a separate Cassandra cluster interacting with the Kubernetes
installation. This is due to the fact that Cassandra Administration is a critical topic, especially with mission critical
workloads. Astarte Operator includes only basic management of Cassandra, and as such it should not be relied upon when
dealing with production environments.

In case an external Cassandra cluster is deployed, be aware that Astarte lives on the assumption it will be the only
application managing the Cluster - as such, it is strongly advised to have a dedicated cluster for Astarte.

## Kubernetes and external components

When deploying external components, it is important to take in consideration how Kubernetes behaves with the underlying
infrastructure. Most modern Cloud Providers have a concept of Virtual Private Cloud, by which the internal Kubernetes
Network stack directly integrates with their Network stack. This, in short, enables deploying Pods in a shared private
network, in which other components (such as Virtual Machines) can be deployed.

This is the preferred, advised and supported configuration. In this scenario, there's literally no difference between
interacting with a VM or a Pod, enabling a hybrid infrastructure without having to pay the performance cost.
