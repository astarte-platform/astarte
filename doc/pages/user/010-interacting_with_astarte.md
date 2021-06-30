# Interacting with Astarte

Astarte's interaction is logically divided amongst two main entities.

*Devices* are the bottom end, and represent your IoT fleet. They can access Astarte only through a Transport, they are defined by a set of [Interfaces](030-interface.html) which, in turn, also define on a very granular level which kind of data they can exchange. By design, they can't access any resource which isn't their own: such a behavior can be configured using Astarte as a middleman to act as a secure Gateway.

*Users* are actual users, applications or anything else which needs to interact directly with Astarte. They are bound to a realm, and can virtually access any resource in that realm given they're authorized to do so. Users can also manage triggers and perform maintenance activity on the Realm.

## User-side Tools

When interacting with Astarte as a User, you have several options to choose from:

* [astartectl](https://github.com/astarte-platform/astartectl): `astartectl` is the main command-line tool to interact with Astarte clusters, which packs
  in a number of subcommands to interact with Astarte API sets. It is a swiss army knife to perform daily operations on Astarte Clusters, and it abstracts
  most Astarte API interactions in a user-friendly way.
* [Astarte Dashboard](015-astarte_dashboard.html): Astarte provides a built-in UI that can be used for managing Interfaces, Devices and Triggers.
  It is meant to be a graphical, user-friendly tool to perform daily operations on Realms.
* Astarte API Clients: API Clients are provided for a variety of languages. These clients abstract API interaction with language-friendly paradigms, and provide
  API automations for several operations. Currently, the main API client available is [astarte-go](https://github.com/astarte-platform/astarte-go).
* Astarte APIs: The base APIs are the lower level interaction layer. They are accessible, in standard installations, at `api.<base Astarte URL>/<apiset>`, and are
  the main mean of interaction upon which all other clients are based upon.
* [Grafana Datasource Plugin for Astarte](080-grafana_datasource.md): Thanks to the Astarte Datasource Plugin, data coming from Astarte
  may be visualised in custom dashboards provided by Grafana, the open source observability platform.


Depending on the context, you might want to choose what suits you best. Over the course of the documentation, several examples will be provided with
interaction means.

### Setting up astartectl

In the documentation, it is assumed that astartectl is [properly configured](https://github.com/astarte-platform/astartectl/tree/v1.0.0-beta.2#configuration) to interact with your Realm or your Cluster. Please refer to its documentation to make sure all needed configurations are in place.

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

* **AppEngine API**: This API is meant for querying/pushing data from/to devices. This maps to `astartectl`'s `astartectl appengine` subcommand.
* **Realm Management API**: This API is meant for configuring a target realm, and most notably for managing triggers. This maps to `astartectl`'s `astartectl realm-management` subcommand.

### Authentication

Authenticating against Astarte is out of the scope of this guide, especially due to the fact that [Astarte does not manage authentication directly](070-auth.html). We'll assume either the authentication isn't enabled, or that the user is always interacting with the APIs with a token with the following claims

```json
{
    "a_aea": ".*:.*",
    "a_rma": ".*:.*"
}
```

Which represents a realm administrator. In real life use cases, you should always make sure to [give out more granular permissions](070-auth.html#granular-claims) and to obtain the token in the right way from your authentication server.

When using `astartectl` or any other client, you can also pass a Realm Private Key as an authentication mean, and have the token be automatically generated for you.

### Accessing the APIs

In a standard Astarte installation, AppEngine API and Realm Management API are usually accessible at `api.<your astarte domain>/appengine` and `api.<your astarte domain>/realmmanagement`.

If your Astarte installation has Swagger UI enabled, you can use the `/swagger` endpoint to access it, and to issue API calls straight from your browser to follow this guide.
