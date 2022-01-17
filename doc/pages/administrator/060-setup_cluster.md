# Setting up the Cluster

Once the Astarte Operator [has been installed](030-installation_kubernetes.html), and any prerequisite
[has been fulfilled](020-prerequisites.html), you can move forward and deploy an Astarte Cluster.

## Using a standard Astarte CR

The standard way of deploying an Astarte instance is by creating your own Astarte Custom Resource.
This gives you an high degree of customization, allowing you to tweak any single parameter in the
Astarte setup. The main Astarte CRD contains [extensive
documentation](https://github.com/astarte-platform/astarte-kubernetes-operator/blob/v1.0.1/config/crd/bases/api.astarte-platform.org_astartes.yaml)
on the available fields in OpenAPIv3 format. Just create your Astarte Custom Resource, which will
look something like this:

```yaml
apiVersion: api.astarte-platform.org/v1alpha1
kind: Astarte
metadata:
  name: astarte
  namespace: astarte
spec:
  # This is the most minimal set of reasonable configuration to spin up an Astarte
  # instance with reasonable defaults and enough control over the deployment.
  version: 1.0.1
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
  # this configuration deploys cassandra in cluster. This is not advised for production environments
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
    sslListener: true
    sslListenerCertSecretName: <your-tls-secret>
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

Starting from Astarte v1.0.1, traffic coming to the broker is TLS terminated ad VerneMQ level. The
two fields controlling this features, namely `sslListener` and `sslListenerCertSecretName` can be
found within the `vernemq` section of the Astarte CR. In a nutshell, their meaning is:
- `sslListener` controls whether TLS termination is enabled at VerneMQ level or not,
- `sslListenerCertSecretName` is the name of TLS secret used for TLS termination (more on how to
  deal with Astarte certificates [here](050-handling_certificates.html)). When `sslListener` is
  true, the secret name **must** be set.

You can simply apply this resource in your Kubernetes cluster with `kubectl apply -f`. The Operator
will take over from there.
