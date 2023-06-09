# Managing Realms

Once the Cluster is set up, you can start managing it by creating Realms.

## Accessing Housekeeping key

When creating a new Cluster, Astarte Operator also creates a brand new keypair and stores it in
the cluster. To retrieve it (assuming you deployed an instance named `astarte` in namespace `astarte`):

```bash
kubectl get secret -n astarte astarte-housekeeping-private-key -o=jsonpath={.data.private-key} | base64 -d > housekeeping.key
```

You can then use `housekeeping.key` to authenticate against Housekeeping API.

## Work in progress

This guide is not yet complete, as this part is a moving target within `astartectl`. Please refer to the
[API Documentation](api/001-intro_api.md) to manage Realms manually once here.
