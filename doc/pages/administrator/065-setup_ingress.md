# Setting up the Ingress

Once your Cluster [is up and running](060-setup_cluster.html), to expose it to the outer world you
need to set up an Ingress. Currently, the only managed and supported Ingress is based upon
[Voyager](https://github.com/appscode/voyager), and this guide will cover only this specific case.

Of course, ensure you have installed [Voyager Operator](https://appscode.com/products/voyager/latest/setup/install/)
before you begin.

## Creating an AstarteVoyagerIngress

Most information needed for exposing your Ingress have already been given in your main Astarte
resource. If your Kubernetes installation supports LoadBalancer ingresses (most managed ones do),
you should be able to get away with the most standard CR:

```yaml
apiVersion: api.astarte-platform.org/v1alpha1
kind: AstarteVoyagerIngress
metadata:
  name: example-minimal
  namespace: astarte
spec:
  # The Astarte Instance the Ingress will be attached to
  astarte: example-minimal
  api:
    exposeHousekeeping: true
  dashboard:
    ssl: true
    host: "dashboard.astarte.yourdomain.com" # When not specified, dashboard will be deployed in /dashboard in the API host.
  letsencrypt:
    use: true
    acmeEmail: info@yourdomain.com
    challengeProvider:
      dns:
        provider: digitalocean
        credentialSecretName: voyager-digitalocean
```

As you might see, there's only one very important thing to be noted: the `astarte` field must reference the name of an
existing Astarte installation in the same namespace, and the Ingress will be configured and attached to that instance.

## SSL and Certificates

Astarte heavily requires SSL in a number of interactions, even though this can be bypassed with `ssl: false`. If you
do not have any SSL Certificates for your domains, you can leverage Voyager's Let's Encrypt integration.
AstarteVoyagerIngress integrates directly with Voyager's native types, and you can follow along
[Voyager's Let's Encrypt guide](https://github.com/appscode/voyager/tree/master/docs/guides/certificate).
Simply set `letsencrypt.use` to `true`, and fill the `challengeProvider` with the right parameters.

## API Paths

`AstarteVoyagerIngress` deploys a well-known tree of APIs to the `host` you specified in the main `Astarte` resource.
In particular, assuming your API host was `api.astarte.yourdomain.com`:

* Housekeeping API base URL will be https://api.astarte.yourdomain.com/housekeeping/v1
* Realm Management API base URL will be https://api.astarte.yourdomain.com/realmmanagement/v1
* Pairing API base URL will be https://api.astarte.yourdomain.com/pairing/v1
* AppEngine API base URL will be https://api.astarte.yourdomain.com/appengine/v1

## Further customization

`AstarteVoyagerIngress` has a number of advanced options that can be used to accommodate needs of the most diverse
deployments. Consult the
[CRD Documentation](https://github.com/astarte-platform/astarte-kubernetes-operator/blob/v0.11.4/deploy/crds/api.astarte-platform.org_astartevoyageringresses_crd.yaml)
to learn more.
