# Migrating to the Astarte Default Ingress

If your Astarte deployment is still being served by the deprecated AstarteVoyagerIngress, it is
highly advised to move to the new managed ingress, namely, the AstarteDefaultIngress.

The current page focuses on describing the procedure for migrating your ingress with ease, simply
employing `astartectl`.

Please, make sure you have read the entirety of this page and to understand all the concepts and the
implications before performing the actual migration.

## Prerequisites and preliminary checks

Before starting with the actual migration procedure, some preliminary activities are required:

- ensure that the version of the Astarte operator in your cluster is at least `>= v1.0.1` and
  stable. If this requirement is not fulfilled, please refer to the [Upgrade
  Procedures](000-upgrade_index.html) section;

- the [`ingress-nginx`](https://kubernetes.github.io/ingress-nginx/) ingress controller must be
  deployed in your cluster (see [this section](020-prerequisites.html#nginx) for the details).
  Be sure of taking note of the `ingress-class` of the controller which is meant to handle your
  Astarte ingress. This information will come handy during the migration itself;

- make sure the TLS secrets used to secure the communications to and from Astarte are deployed. For
  the details, please refer to the [Handling Astarte certificates](050-handling_certificates.html)
  page;

- ensure that [`astartectl`](https://github.com/astarte-platform/astartectl) is installed on your
  machine and its version is at least `>= v1.0.0`.

## Performing the migration

Performing the actual ingress migration is as simple as executing an `astartectl` command:

```bash
$ astartectl cluster instances migrate replace-voyager
```

The `replace-voyager` command provides meaningful defaults so that, if your Astarte deployment
relies on standard naming practices, you can simply omit all the flags.

The following list of options is available:
- `--namespace`: the namespace in which the Astarte instance resides (default: "astarte");
- `--operator-name`: the name of the Astarte Operator instance (default:
  "astarte-operator-controller-manager");
- `--operator-namespace`: the namespace in which the Astarte Operator resides (default:
  "kube-system");
- `--ingress-name`: the name of the AstarteVoyagerIngress to be migrated. When not set, the first
  ingress found in the cluster will be selected.

  To find the AstarteVoyagerIngress resources present in your cluster simply run:
  ```bash
  $ kubectl get avi -n <astarte-namespace>
  ```
- `--out`: the name of the file in which the AstarteVoyagerIngress custom resource will be saved
  (optional).

To successfully complete the procedure, you will be prompted to interactively insert details such
as:
- the name of the Astarte TLS secrets,
- the name of the to-be-installed AstarteDefaultIngress resource,
- the ingress class of the NGINX ingress controller.

Before starting the migration routine, you will be asked to review the generated
AstarteDefaultIngress custom resource. The migration will start only upon confirmation.

Please, note that you can contextually dump your AstarteVoyagerIngress custom resource for backup
purposes simply using the `--out <filename>` option.

### What happens under the hood?

When invoking the `replace-voyager` command, `astartectl` interacts with your Astarte cluster and
retrieves the AstarteVoyagerIngress resource which serves your Astarte instance. If no
AstarteVoyagerIngresses are present, the procedure is immediately terminated as there is nothing to
migrate.

After all the required information is provided through the interactive prompt, the
AstarteDefaultIngress resource is reviewed and the final confirmation is provided, the following
tasks are performed:
- the Astarte resource is patched so that TLS termination is handled at the VerneMQ level: in
particular, the fields `sslListener` and `sslListenerCertSecretName` are populated;
- the AstarteDefaultIngress resource is installed within your cluster. Once installed, the Astarte
Operator takes over and ensures that:
  - a service of kind LoadBalancer is created to serve the Astarte broker,
  - an ingress resource is created to serve the Astarte APIs (and the Dashboard, if requested).

If one of the previous tasks are not successful, the migration logic is reverted as not to leave
your cluster in a broken state.

At the end of the procedure, after the AstarteDefaultIngress is successfully created, the old
AstarteVoyagerIngress resource will be deleted. Anyway, if any errors occur during the deletion of
the AstarteVoyagerIngress, the migration procedure is not reverted (as the AstarteDefaultIngress
resource is successfully deployed) and, as such, you are required to explicitly delete the
AstarteVoyagerIngress resource by hand.

Be aware that Voyager specific annotations cannot be mapped to the AstarteDefaultIngress. If any of
those annotations are present, the `replace-voyager` command will print a warning message. It will
be your responsibility confirming whether you want to proceed or abort the procedure.

## Advanced use cases

The current section focuses on some advanced configuration scenarios that might help you in handling
specific non-standard use cases.

### Preserve the API and Broker IPs

The need of preserving both the API and Broker IPs may arise in specific use cases when, for
example, there are any number of impediments in updating your DNS zones.

Please, be aware that the following instructions rely on the assumption that you can reserve (or you
already reserved) external IPs. This task is highly dependent on your cloud service provider and, as
such, you are required to ensure that it can be performed in your specific case.

If your Astarte instance is exposed to the outer world through the AstarteVoyagerIngress, two
external IPs are assigned to your services: one for the Broker and another for the Astarte APIs (and
the dashboard, if deployed).

Before migrating your ingress to the AstarteDefaultIngress, perform the following operations:
- ensure that both the API and the Broker IPs are reserved,
- patch your AstarteVoyagerIngress resource such that the `loadBalancerIP` field is set for the
  broker (if this field is already set, you can skip this step):
  ```yaml
  broker:
    loadBalancerIP: <the-broker-reserved-IP>
    ...
  ```
- install (or update, if already installed) the `ingress-nginx` deployment by explicitly setting the
  IP for the ingress controller as to make it coincident with the IP assigned to the Astarte APIs.
  Be aware that, at first, the ingress controller external IP will remain in pending state until the
  AstarteVoyagerIngress will be deleted and, once that IP will be available, it will be correctly
  assigned to the ingress controller.
  ```bash
  $ helm upgrade --install <ingress-nginx-name> ingress-nginx/ingress-nginx \
    -n ingress-nginx \
    --set controller.service.externalTrafficPolicy=Local \
    --set controller.service.loadBalancerIP=<the-API-reserved-IP>
  ```

Once the previous instructions are executed, you are ready to perform the migration to the
AstarteDefaultIngress as described in the [Performing the Migration](#performing-the-migration)
section.

As a final remark, if you are interested in preserving only one of the external IPs, please refer
only to the instructions that apply to your needs (e.g.: the broker) while neglecting the remaining
parts.
