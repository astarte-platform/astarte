# Handling Astarte certificates

Astarte heavily requires SSL in a number of interactions, even though this can be bypassed with
`ssl: false`.

In general, there are two alternative scenarios when dealing with certificates:
- you already purchased SSL certificates for your domains,
- you want your certificates to be handled by Let's Encrypt through cert-manager.

The two alternative procedures for securing your Astarte deployment are outlined in the following
sections.

## Use your own certificates

If you already own certificates for your domains, all it's needed is creating a TLS secret in the
namespace in which Astarte resides. Assuming that the certificate and key are saved respectively as
`cert.pem` and `privkey.pem`, simply run:

```bash
$ kubectl create secret tls astarte-tls-cert -n astarte \
  --cert=cert.pem --key=privkey.pem
```

## Use Let's Encrypt certificates with cert-manager

The process of obtaining a TLS certificate from Let's Encrypt is handled by cert-manager using a
cluster issuer. The issuer will query the Let's Encrypt API and handles the challenge to confirm
that you are the right owner of the specified domain. Two types of challenges are supported, namely
DNS01 and HTTP01.

Ensure all the [prerequisites](020-prerequisites.html) are satisfied and that both cert-manager and
the NGINX ingress controller are deployed within your cluster. If you haven't installed them yet,
you can do it with these simple commands:

- install cert-manager:
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
- install NGINX ingress controller:
```bash
$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
$ helm repo update
$ helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx \
    --set controller.service.externalTrafficPolicy=Local \
    --create-namespace
```

### HTTP01 Challenge

The current section outlines the procedure for setting up a ClusterIssuer to solve the HTTP01
challenge.

#### Find the external IP assigned to the ingress controller

Knowing the external IP of the NGINX ingress controller is crucial for solving the HTTP01 challenge.
You can find the external IP under the `EXTERNAL-IP` field when inspecting the output of the
following command:

```bash
$ kubectl get svc -n ingress-nginx ingress-nginx-controller
```

#### Configure your DNS

Once the external IP of the ingress controller is known, make sure all your Astarte domains point to
the NGINX Ingress controller IP. In particular, the list of the domains is:

- `api.your-domain.example.com`
- `dashboard.your-domain.example.com` (if deployed)
- `broker.your-domain.example.com`

#### Create a ClusterIssuer

Define a ClusterIssuer and save it as `cluster-issuer.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@email.com
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
```

Then, apply the resource with the following:

```bash
$ kubectl apply -f cluster-issuer.yaml
```

#### Create a Certificate resource

Once the ClusterIssuer has been created, add a `Certificate` resource in the Astarte namespace
referencing the `ClusterIssuer`, and save it as `certificate.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: astarte-default-ingress-certificate
  namespace: astarte
spec:
  dnsNames:
    - <your-dns.names>
  secretName: astarte-tls-cert
  issuerRef:
    name: letsencrypt
    kind: ClusterIssuer
```

Then, apply the `Certificate` resource:
```bash
$ kubectl apply -f certificate.yaml
```

#### Wait the HTTP challenge to complete

As soon as the HTTP challenge completes, a Kubernetes secret of type `kubernetes.io/tls` called
`astarte-tls-cert` will be created in the `astarte` namespace. Now you can reference the TLS secret
in both the Astarte and AstarteDefaultIngress resources where required.

### DNS01 challenge

The current section describes the procedure for setting up a `ClusterIssuer` to use Google CloudDNS
to solve the DNS01 challenge. Therefore, when needed, the rest of this section will make use of the
`gcloud CLI`.

If your Astarte deployment is hosted by another cloud provider, please refer to the cert-manager
specific [documentation](https://cert-manager.io/docs/configuration/acme/dns01/).

#### Define a DNS Zone for your project

First, ensure that a **DNS Zone is already defined for your project**. If this requirement is not
satisfied, this [page](https://cloud.google.com/dns/docs/zones) provides guidance for the creation
of the DNS Zone for a project hosted on Google Cloud. If your cluster is hosted by any other cloud
provider, please ensure to follow the needed steps to fulfill the requirement.

#### Set up a Service Account with privileges of DNS Administrator

To set up a service account with privileges of DNS Administrator, run the following command:

```bash
$ PROJECT_ID=<your-project-id>
$ gcloud iam service-accounts create dns01-solver --display-name "dns01-solver"
$ gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member serviceAccount:dns01-solver@$PROJECT_ID.iam.gserviceaccount.com \
    --role roles/dns.admin
```

#### Create a Service Account secret

To access the service account, cert-manager uses a key stored in a Kubernetes Secret. Therefore,
create a key and download it as a json file:

```bash
$ gcloud iam service-accounts keys create key.json \
    --iam-account dns01-solver@$PROJECT_ID.iam.gserviceaccount.com
```

and create a secret named `clouddns-dns01-solver-svc-acct` in the `cert-manager` namespace from the
`key.json` file:

```bash
$ kubectl create secret generic -n cert-manager \
    clouddns-dns01-solver-svc-acct \
   --from-file=key.json
```

#### Create a ClusterIssuer that uses CloudDNS

Define a `ClusterIssuer` resource which uses the secret, and save it as `cluster-issuer.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns-cluster-issuer
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@email.com
    privateKeySecretRef:
      # Secret resource that will be used to store the account's private key.
      name: letsencrypt-cluster-issuer-key
    solvers:
    - dns01:
        cloudDNS:
          # The ID of the GCP project
          project: <your-project-id>
          # This is the secret used to access the service account
          serviceAccountSecretRef:
            name: clouddns-dns01-solver-svc-acct
            key: key.json
```

Apply the resource simply running the following:

```bash
$ kubectl apply -f cluster-issuer.yaml
```

#### Create a Certificate resource

Once the ClusterIssuer has been created, add a `Certificate` resource in the Astarte namespace
referencing the `ClusterIssuer`, and save it as `certificate.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: astarte-default-ingress-certificate
  namespace: astarte
spec:
  dnsNames:
    - <your-dns.names>
  secretName: astarte-tls-cert
  issuerRef:
    name: letsencrypt-dns-cluster-issuer
    kind: ClusterIssuer
```

Thus, apply the `Certificate` resource:
```bash
$ kubectl apply -f certificate.yaml
```

#### Wait the DNS challenge to complete

As soon as the DNS challenge completes, a Kubernetes secret of type `kubernetes.io/tls` called
`astarte-tls-cert` will be created in the `astarte` namespace. Now you can reference the TLS secret
in both the Astarte and AstarteDefaultIngress resources where required.

## Conclusions

The current page describes how to handle SSL certificates for securing your Astarte instance. In
particular the following use cases are analyzed:

- certificates have already been purchased and needs to be properly deployed,
- let cert-manager generate and handle certificates in the following cases:
  - solving HTTP01 ACME challenges,
  - solving DNS01 ACME challenges.

At the end of each procedure you will end up with a Kubernetes TLS secret, named `astarte-tls-cert`,
deployed in the Astarte namespace. Reference the secret in your Astarte and AstarteDefaultIngress
resources where required to secure your Astarte deployment.
