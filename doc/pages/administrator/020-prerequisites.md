# Prerequisites

As much as Astarte's Operator is capable of creating a completely self-contained installation,
there's a number of prerequisites to be fulfilled depending on the use case.

## On your machine

In your local machine, you'll need two main tools:
[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and
[astartectl](https://github.com/astarte-platform/astartectl).

Ensure you have a `kubectl` version matching your target Kubernetes cluster version, and a recent
`astartectl` version.

## NGINX

Astarte currently features only one supported Managed Ingress, based on
[NGINX](https://nginx.org/en/). NGINX provides routing, SSL termination and more,
and as of today is the preferred/advised way to run Astarte in production.

Astarte Operator is capable of interacting with NGINX through its dedicated
`AstarteDefaultIngress` resource, as long as an [NGINX ingress
controller](https://kubernetes.github.io/ingress-nginx/) is installed. Installing the ingress
controller is as simple as running a few `helm` commands:
```bash
$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
$ helm repo update
$ helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx \
    --set controller.service.externalTrafficPolicy=Local \
    --create-namespace
```

You don't need to create NGINX ingresses yourself - just the Operator itself is enough.

## Voyager (deprecated)

Until Astarte v1.0.0, the only supported Managed Ingress was the
[Voyager](https://github.com/appscode/voyager) based `AstarteVoyagerIngress`. Starting from Dec the
31st 2021, according to the [Voyager
announcement](https://blog.byte.builders/post/voyager-v2021.09.15/), the support for Voyager will be
dropped as stated [here](https://github.com/astarte-platform/astarte/issues/613). An alternative
NGINX based Managed Ingress has been developed to replace the Voyager based solution (for reference,
see the previous section).

## cert-manager

Astarte requires [`cert-manager`](https://cert-manager.io/) to be installed in the cluster in its
default configuration (installed in namespace `cert-manager` as `cert-manager`). If you are using
`cert-manager` in your cluster already you don't need to take any action - otherwise, you will need
to install it.

Astarte is actively tested with `cert-manager` 1.7, but should work with any 1.0+ releases of
`cert-manager`. If your `cert-manager` release is outdated, please consider upgrading to a newer
version according to [this guide](https://cert-manager.io/docs/installation/upgrading/).

[`cert-manager` documentation](https://cert-manager.io/docs/installation/) details all needed steps
to have a working instance on your cluster - however, in case you won't be using `cert-manager` for
other components beyond Astarte or, in general, if you don't have very specific requirements, it is
advised to install it through its Helm chart. To do so, run the following commands:

```bash
$ helm repo add jetstack https://charts.jetstack.io
$ helm repo update
$ kubectl create namespace cert-manager
$ helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.7.0 \
  --set installCRDs=true
```

This will install `cert-manager` 1.7.0 and its CRDs in the cluster.

## External Cassandra / Scylla

In production deployments, it is strongly advised to have a separate Cassandra cluster interacting
with the Kubernetes installation. This is due to the fact that Cassandra Administration is a
critical topic, especially with mission critical workloads. Astarte Operator includes only basic
management of Cassandra, which is deprecated since v1.0 and as such it should not be relied upon
when dealing with production environments. Furthermore, in the near future, Cassandra support is
planned to be removed from Astarte Operator in favor of the adoption of a dedicated Kubernetes
Operator (e.g. [Scylla Operator](https://operator.docs.scylladb.com/stable/generic.html)).

In case an external Cassandra cluster is deployed, be aware that Astarte lives on the assumption it
will be the only application managing the Cluster - as such, it is strongly advised to have a
dedicated cluster for Astarte.

## Kubernetes and external components

When deploying external components, it is important to take in consideration how Kubernetes behaves
with the underlying infrastructure. Most modern Cloud Providers have a concept of Virtual Private
Cloud, by which the internal Kubernetes Network stack directly integrates with their Network stack.
This, in short, enables deploying Pods in a shared private network, in which other components (such
as Virtual Machines) can be deployed.

This is the preferred, advised and supported configuration. In this scenario, there's literally no
difference between interacting with a VM or a Pod, enabling a hybrid infrastructure without having
to pay the performance cost.
