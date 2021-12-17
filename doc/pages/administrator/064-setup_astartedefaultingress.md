# Setting up Astarte Default Ingress

Once your Cluster [is up and running](060-setup_cluster.html), to expose it to the outer world you
need to set up an Ingress. Currently, the **only managed and supported Ingress** is based upon
[NGINX](https://nginx.org/en/), and this guide will cover only this specific case.

Please, note that the previously supported Voyager based ingress is deprecated and should not be
used (see the [Voyager announcement](https://blog.byte.builders/post/voyager-v2021.09.15/) and the
related Astarte [issue](https://github.com/astarte-platform/astarte/issues/613) for further
details).

If you want to migrate away from AstarteVoyagerIngress to the new AstarteDefaultIngress, please
refer to the procedure outlined [here](030-upgrade_100_101.html).

## Prerequisites

Before proceeding with the deployment of the Astarte Default Ingress, the following requirements
must be fulfilled:

- TLS certificates must be deployed as a secret within the namespace in which Astarte resides (see
  the [Handling Astarte Certificates](050-handling_certificates.html) section). To check if the TLS
  secret is correctly deployed, you can run:
  ```bash
  $ kubectl get secrets -n astarte
  ```
  and make sure your certificate is stored in a secret of type `kubernetes.io/tls` in that list;
- Astarte must be configured such that TLS termination is handled at VerneMQ level: this can be done
  simply editing the Astarte resource and, in the `vernemq` section, setting the `sslListener` and
  `sslListenerCertSecretName`. Your Astarte CR will look something like:
  ```yaml
  apiVersion: api.astarte-platform.org/v1alpha2
  kind: Astarte
  ...
  spec:
    ...
    vernemq:
      sslListener: true
      sslListenerCertSecretName: <your-tls-secret-name>
      ...
  ```
- [`ingress-nginx`](https://kubernetes.github.io/ingress-nginx/) ingress controller **must be
deployed** within your cluster. You can install it following the instructions reported
[here](020-prerequisites.html#nginx).

## Creating an `AstarteDefaultIngress`

Most information needed for exposing your Ingress have already been given in your main Astarte
resource. If your Kubernetes installation supports LoadBalancer ingresses (most managed ones do),
you should be able to get away with the most standard CR:

```yaml
apiVersion: ingress.astarte-platform.org/v1alpha1
kind: AstarteDefaultIngress
metadata:
  name: adi
  namespace: astarte
spec:
  ### Astarte Default Ingress CRD
  astarte: astarte
  tlsSecret: <your-astarte-tls-cert>
  api:
    exposeHousekeeping: true
  dashboard:
    deploy: true
    ssl: true
    host: <your-astarte-dashboard-host>
  broker:
    deploy: true
    serviceType: LoadBalancer
    # loadBalancerIP is needed if your certificate is obtained with the solution of the HTTP
    # challenge, othewise it's optional. Please, be aware that the possibilities and modes for
    # assigning a loadBalancerIP to a service depend on your cloud provider.
    loadBalancerIP: <your-loadbalancerIP>
```

There's one very important thing to be noted: the `astarte` field must reference the name of an
existing Astarte installation in the same namespace, and the Ingress will be configured and attached
to that instance.

## What happens after installing the AstarteDefaultIngress resource?

When the AstarteDefaultIngress resource is created, the Astarte Operator ensures that the following
resources are created according to your configuration:
- an NGINX ingress which is devoted to routing requests to the Astarte APIs and to the Astarte
  Dashboard,
- a service of kind LoadBalancer which exposes the Astarte broker to the outer world.

The following commands will help you in the task of retrieving the external IPs assigned to both the
ingress and the broker service. Assuming that your Astarte instance and AstarteDefaultIngress are
respectively named `astarte` and `adi`, and that they are deployed within the `astarte` namespace,
simply run:

```bash
$ # retrieve information about the ingress
$ kubectl get ingress -n astarte
NAME              CLASS   HOSTS          ADDRESS   PORTS     AGE
adi-api-ingress   nginx   <your-hosts>   X.Y.W.Z   80, 443   6s
```

and

```bash
$ # retrieve information about the broker service
$ kubectl get service -n astarte adi-broker-service
NAME                 TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)         AGE
adi-broker-service   LoadBalancer   x.x.x.x        A.B.C.D       443:32149/TCP   17s
```

## SSL and Certificates

Astarte heavily requires SSL in a number of interactions, even though this can be bypassed with
`ssl: false`. If you do not have any SSL certificates for your domains, you can leverage
cert-manager capabilities. Simply follow the instructions outlined
[here](050-handling_certificates.html) to learn how to handle your certificates.

## How to support automatic certificate renewal for HTTP challenges?

When your certificate is issued after the solution of an HTTP challenge, to ensure the renewal of
the certificate itself you must ensure that the NGINX ingress and the broker service are exposed on
the same external IP.

Given that the ingress external IP is obtained after the deployment of the NGINX ingress controller,
all you have to do is ensuring that the broker service is exposed on the ingress IP. Thus, set the
`loadBalancerIP` field in your AstarteDefaultIngress resource:

```yaml
apiVersion: ingress.astarte-platform.org/v1alpha1
kind: AstarteDefaultIngress
...
spec:
  ...
  broker:
    deploy: true
    serviceType: LoadBalancer
    loadBalancerIP: <same-IP-of-your-ingress>
```

Please, be aware that the possibility of setting the `loadBalancerIP` is dependent on your cloud
provider. For example, if your Astarte instance is hosted by Google, you will need to reserve the IP
before assigning it to the broker service (see [this
page](https://cloud.google.com/compute/docs/ip-addresses/reserve-static-external-ip-address#promote_ephemeral_ip)
for further details). Discussing how other cloud providers handle this specific task is out of the
scope of this guide and is left to the reader.

## API Paths

`AstarteDefaultIngress` deploys a well-known tree of APIs to the `host` you specified in the main
`Astarte` resource.

In particular, assuming your API host was `api.astarte.yourdomain.com`:

* Housekeeping API base URL will be: `https://api.astarte.yourdomain.com/housekeeping`
* Realm Management API base URL will be: `https://api.astarte.yourdomain.com/realmmanagement`
* Pairing API base URL will be: `https://api.astarte.yourdomain.com/pairing`
* AppEngine API base URL will be: `https://api.astarte.yourdomain.com/appengine`

## Further customization

`AstarteDefaultIngress` has a number of advanced options that can be used to accommodate needs of
the most diverse deployments. Consult the [CRD
Documentation](https://github.com/astarte-platform/astarte-kubernetes-operator/blob/release-1.0/config/crd/bases/ingress.astarte-platform.org_astartedefaultingresses.yaml)
to learn more.
