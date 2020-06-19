# Setting up the Cluster

Once the Astarte Operator [has been installed](030-installation_kubernetes.html), and any prerequisite
[has been fulfilled](020-prerequisites.html), you can move forward and deploy an Astarte Cluster.

## Using astartectl

You can use `astartectl` to deploy an instance through the `astartectl cluster instances deploy` command.
This is an interactive command that will inspect your cluster and provide you with a set of profiles that
can be deployed. When you choose a Profile, you will be prompted with a number of questions that will
be needed to configure your instance correctly. Upon completion, `astartectl` will prepare and execute the
deployment automatically.

## astartectl Profiles

In `astartectl`, profiles allow for easy scaling, enhanced management, and automated upgrade upon release
series without any action on behalf of the user. They're the way to go if you plan on having a standard,
managed installation.

`astartectl` comes packed with a set of default profiles, but you can write your own ones. Profiles can
be either written as Go resources, or (in a much easier fashion) as `yaml` resources. You can have a look
at the [Profiles schema here](https://github.com/astarte-platform/astartectl/blob/release-1.0/cmd/cluster/deployment/astarte_cluster_profile.go).

### Writing your own profile

This guide will be extended in the future, as more recent versions of `astartectl` will support loading yaml
profiles.

## Using a standard Astarte CR

If you do not want to use `astartectl` or Profiles, you can create your own Astarte Custom Resource. This gives you
a higher degree of customization, allowing you to tweak any single parameter in the Astarte setup. The main
Astarte CRD contains
[extensive documentation](https://github.com/astarte-platform/astarte-kubernetes-operator/blob/release-1.0/deploy/crds/api.astarte-platform.org_astartes_crd.yaml)
on the available fields in OpenAPIv3 format. Just create your Astarte Custom Resource, which will look something
like this:

```yaml
apiVersion: api.astarte-platform.org/v1alpha1
kind: Astarte
metadata:
  name: example-minimal
  namespace: astarte
spec:
  # This is the most minimal set of reasonable configuration to spin up an Astarte
  # instance with reasonable defaults and enough control over the deployment.
  version: 1.0.0-alpha.1
  api:
    host: "api.astarte.yourdomain.com" # MANDATORY
  rabbitmq:
    resources:
      requests:
        cpu: 300m
        memory: 512M
      limits:
        cpu: 1
        memory: 1000M
  cassandra:
    maxHeapSize: 1024M
    heapNewSize: 256M
    storage:
      size: 30Gi
    resources:
      requests:
        cpu: 1
        memory: 1024M
      limits:
        cpu: 2
        memory: 2048M
  vernemq:
    host: "broker.astarte.yourdomain.com"
    resources:
      requests:
        cpu: 200m
        memory: 1024M
      limits:
        cpu: 1000m
        memory: 2048M
  cfssl:
    resources:
      requests:
        cpu: 100m
        memory: 128M
      limits:
        cpu: 200m
        memory: 256M
    storage:
      size: 2Gi
  components:
    # Global resource allocation. Automatically allocates resources to components weighted in a
    # reasonable way.
    resources:
      requests:
        cpu: 1200m
        memory: 3072M
      limits:
        cpu: 3000m
        memory: 6144M
```

You can simply apply this resource in your Kubernetes cluster with `kubectl apply -f`. The Operator will take
over from there.
