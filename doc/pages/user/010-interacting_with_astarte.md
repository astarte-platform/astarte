# Interacting with Astarte

Astarte's interaction is logically divided amongst two main entities.

*Devices* are the bottom end, and represent your IoT fleet. They can access Astarte only through a Transport, they are defined by a set of [Interfaces](030-interface.html) which, in turn, also define on a very granular level which kind of data they can exchange. By design, they can't access any resource which isn't their own: such a behavior can be configured using Astarte as a middleman to act as a secure Gateway.

*Users* are actual users, applications or anything else which needs to interact directly with Astarte. They are bound to a realm, and can virtually access any resource in that realm given they're authorized to do so. Users can also manage triggers and perform maintenance activity on the Realm.

## Interacting with a Device

Devices interact with Astarte through their associated Transport. In this guide, we'll assume the Transport is MQTT/VerneMQ as per Astarte's defaults.

However, rather than implementing the whole Astarte protocol over MQTT, it is usually a better idea to rely on one of [Astarte's SDKs](https://github.com/search?q=org%3Aastarte-platform+sdk).

### Authentication/Pairing

Depending on how you plan on implementing [Astarte's pairing mechanism](050-pairing_mechanism.html), your devices might need an Agent for their first authentication or not. However, once they retrieve their Credentials Secret, they can implement Astarte's standard pairing routine to rotate their SSL certificate for accessing the transport.

In the most likely scenario in which you are using one of Astarte's SDKs, the SDK takes care of the whole pairing routine under the hood and, depending on your agent implementation, you just need to feed the SDK with either the Credentials Secret or the Agent Key.

### Exchanging data

As per Astarte's protocol specification, data is exchanged based on the device's introspection. The device will be able to publish data on the transport on `device` interfaces, and receive data on `server` interfaces. In the MQTT case, the device will subscribe to its `server` interfaces' topics, and publish on its `device` interfaces topics.

Isolation and RBAC are guaranteed by the transport's ACL, which are usually orchestrated though a dedicated Astarte extension (as in the VerneMQ/MQTT case).

Again, Astarte's SDK allows you to interact with your device interfaces directly without caring about the underlying protocol and exchange details.

## Interacting as a User

Astarte is mainly accessed through its APIs. Astarte's APIs are exposed through dedicated microservices (see [Components](020-components.html)) and are meant both for configuration and for accessing data. There are two main sets of APIs we'll be using frequently:

 * **AppEngine API**: This API is meant for querying/pushing data from/to devices.
 * **Realm Management API**: This API is meant for configuring a target realm, and most notably for managing triggers.

### Authentication

Authenticating against Astarte is out of the scope of this guide, especially due to the fact that [Astarte does not manage authentication directly](070-auth.html). We'll assume either the authentication isn't enabled, or that the user is always interacting with the APIs with a token with the following claims

```json
{
    "a_aea": ".*:.*",
    "a_rma": ".*:.*"
}
```

Which represents a realm administrator. In real life use cases, you should always make sure to [give out more granular permissions](070-auth.html#granular-claims) and to obtain the token in the right way from your authentication server.

### Accessing the APIs

In a standard Astarte installation, AppEngine API and Realm Management API are usually accessible at `app.api.<your astarte domain>` and `realm.api.<your astarte domain>` respectively, or at `api.<your astarte domain>/app` and `api.<your astarte domain>/realm`.

If your Astarte installation has Swagger UI enabled, you can use the `/swagger` endpoint to access it, and to issue API calls straight from your browser to follow this guide.
