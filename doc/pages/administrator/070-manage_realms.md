# Managing Realms

Once the Cluster is set up, you can start managing it by creating Realms.

## Accessing Housekeeping key

When creating a new Cluster, Astarte Operator also creates a brand new keypair and stores it in
the cluster. To retrieve it (assuming you deployed an instance named `astarte` in namespace `astarte`):

```bash
kubectl get secret -n astarte astarte-housekeeping-private-key -o=jsonpath={.data.private-key} | base64 -d > housekeeping.key
```

You can then use `housekeeping.key` to authenticate against Housekeeping API.

## Device limit in a Realm
While there is no limit on the number of Devices registered in a Realm, it is possible to impose
an upper bound using the `<astarte base API URL>/housekeeping/v1/realms/<realm name>` API.
By default, such an upper bound does not exist. The limit can be retrieved, updated or removed
(meaning that any number of registered Devices is allowed).

### Setting, updating or removing the limit on the number of registered Devices in a Realm

`PATCH <astarte base API URL>/housekeeping/v1/realms/<realm name>`

The HTTP payload of the request must have the following format:

```json
{
    "data": {
        "device_registration_limit": <value>
    }
}
```

To set or update the limit, the value must be a non negative integer.
If the value is less than the number of currently registered devices, no devices will be
removed, but it will not be possible to register new devices.
When it is set, trying to register more Devices past the limit will result in an error.
To remove the limit, the value must be `null`.

### Fetching the limit on the number of registered Devices in a Realm

`GET <astarte base API URL>/housekeeping/v1/realms/<realm name>`

The HTTP payload of the response will have the following format:

```json
{
  "data": {
    "realm_name": <realm name>,
    "jwt_public_key_pem": <realm public key>,
    "replication_factor": <realm replication factor>,
    "device_registration_limit": <realm device registration limit>
  }
}
```

If no limit is currently set, the value of the `"device_registration_limit"` field will be `null`.

## Work in progress

This guide is not yet complete, as this part is a moving target within `astartectl`. Please refer to the
[API Documentation](api/001-intro_api.md) to manage Realms manually once here.
