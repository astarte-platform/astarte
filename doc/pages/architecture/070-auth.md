# Authentication and Authorization

Authentication and authorization are crucial, as Astarte likely holds sensitive resources and is capable to send mass commands to a device fleet.

First of all: when talking about auth in Astarte, we are talking about anything which isn't a Device - those are Authenticated through [Pairing](030-pairing_mechanism.html) and Authorized by their Transport (which uses Pairing for the Authentication policies).

Astarte's authentication/authorization stage identifies the principal through a token (with JWT as the first class citizen), which is the only currency the platform supports.

## Authentication Realms

In Astarte, realms are logically separated and have completely different data partitions. This is also true in terms of authentication, as caller is always authenticated on a per-realm basis. As such, an authentication realm matches 1:1 an Astarte realm.

Superadmin APIs, such as housekeeping, are part of a different authentication realm which is defined upon cluster setup.

## Authentication in Astarte

Astarte, by design, does not have a concept of per-user authentication built in. The definition of an authentication realm is a mean to verify a token's validity, that is most likely a public key.

This makes integrating Astarte with 3rd party authentication/authorization frameworks and SSOs extremely easy, as the whole logic for addressing user management is managed out of the cluster by a dedicated party. Depending on one's use case, it is possible to use either a very simple, dedicated OAuth server for each realm, or a full fledged SSO such as [Keycloak](http://www.keycloak.org/) which matches its authentication realms to Astarte's realms. Especially if you are aiming at the latter, make sure to read the advised [best practices for authentication](#best-practices) afterwards.

## Authorization

Currently, Astarte supports a URL-based authorization for the API. Given that Astarte's data access APIs match the devices' topology like a tree, declaring the authorization in terms of path whitelisting gives enough flexibility to give each user the correct permissions without limitations.

As said, Astarte does not have the concept of user, and neither has a durable storage which tracks permissions. As such, it expects the authorization information to be inside the token, which is the only entity Astarte can trust - given it has been verified and authenticated through its signature.

Paths are given in form of a set of [Perl-like Regular Expressions](https://perldoc.perl.org/perlre.html), and on a per-API basis. This means that each API endpoint (app, realm, etc...) has its own regular expression which defines what the user can do. Moreover, each HTTP verb in an API endpoint (e.g.: GET, POST, PUT, DELETE) can have its own regular expression, to fine-grain permissions on each path.

*Note: given Astarte's interface are either read only or write only, HTTP verb fine-graining in AppEngine API is mostly useful for preventing a user from deleting a consumer Datastream even though it has write access to it. Most of the time, using only a single regular expression with no verb fine-graining works.*

Examples of valid regular expressions on AppEngine API are:

 * `POST::devices/.*/interfaces/com\\.my\\.interface/.*`: Allows to set individual values on the `com.my.interface` interface on any individual device in the realm.
 * `.*::.*/interfaces/com\\.my\\.monitoring\\.interface.*`: Allows to get/set/delete either the aggregate or the individual values of the `com.my.monitoring.interface` interface on any device or device aggregation in the realm.
 * `.*::devices/j0zbvbQp9ZNnanwvh4uOCw.*`: Allows every operation on device `j0zbvbQp9ZNnanwvh4uOCw`
 * `GET::devices/[a-zA-Z0-9-_]*`: Allows to get every individual device's status, but denies access to any additional information/operation on them.

Examples of valid regular expressions on Realm Management API are:

 * `POST::interfaces\/.*`: Allows installing new interfaces in the realm.
 * `GET::interfaces\/.*`: Allows inspecting every interface in the realm.
 * `PUT::interfaces\/.*\/0`: Allows updating all draft interfaces in the realm.

Other valid examples are:

 * `.*::.*`: Allows any operation on the given API.

Both verb and path regular expressions are implicitly delimited by adding `^` before and `$` after the regular expression string. For example, if you use `GET::interfaces` as regular expression in Realm Management API, the path will be matched against `^GET$` and the path will be matched against `^interfaces$`. This way the only operation allowed will be listing all the interfaces, while all operation on `interfaces/` subpaths will be denied.

### Token claims and formats

Authorization regular expressions have to be contained in the token's claims. Only the JWT case will be considered given it is the primary currency Astarte supports. Every claim is an array of regular expressions, which act as a logical OR. A similar behavior could be of course achieved (and might be more efficient) with a singular regular expression, but for the sake of readability and simplicity it is allowed nonetheless. Of course, keeping the authorization claims simple and pragmatic helps in terms of performance.

Supported token claims are:

 * `a_aea`: Defines the regular expressions for AppEngine API
 * `a_rma`: Defines the regular expressions for Realm Management API
 * `a_hka`: Defines the regular expressions for Housekeeping API
 * `a_pa`: Defines the regular expressions for Pairing API
 * `a_ch`: Defines the regular expressions for Channels

Of course, claims are considered only after a successful token verification. This means that the claim will be processed only if the caller is authenticated against the correct authentication realm  - this is especially the case for what concerns Housekeeping, which has a dedicated Authentication realm not tied to any Astarte realms.

An example of a valid token claim is:

```json
{
	"a_aea": ["GET::devices/[a-zA-Z0-9-_]*",
	         ".*::.*/interfaces/com\\.my\\.monitoring\\.interface.*",
	         ".*::devices/j0zbvbQp9ZNnanwvh4uOCw.*"],
	"a_rma": ["GET::.*"]
}
```

Which allows very specific permissions on AppEngine API, and a "read all" on Realm Management API.

The client by default has no permission to do anything: as such, if a token is missing a claim it is simply assumed that the client isn't authorized to access that specific API. However, keeping in mind that Astarte has no concept of User, it is also true that your authentication backend might choose to emit a different token with only a subset of its real permissions to keep claims and regular expressions as pragmatic as possible. See [Granular Claims in Best Practices](#granular-claims) for more details on this.

### Natively supported tokens

Astarte supports only JWT natively, which has to be signed using one of the following algorithms:

 * ES256
 * ES384
 * ES512
 * PS256
 * PS384
 * PS512
 * RS256
 * RS384
 * RS512

## Authorization for REST APIs

Valid tokens can be used for calling into Astarte's public APIs. Depending on which token mechanism is used, the HTTP call must adhere to some requirements.

### JWT

Every API call **must** have an `Authorization: Bearer <token>` header. Not providing the token or providing a token which can't be validated for the authentication realm of the context results in a 401 reply.

## Authorization for Channels

A valid token should be supplied when opening the WebSocket, in the very same fashion to what happens with REST APIs. However, the claims in this token will support different verbs compared to the REST APIs, namely `JOIN` and `WATCH`. These have very specific meanings and are well explained in [Channels' User Guide](052-using_channels.html#authorization).

The behavior and supported tokens are equivalent to REST APIs.

## Supported integrations

Astarte, by default, is extremely easy to configure assuming your chosen SSO is capable of issuing JWT, as it is currently the only natively supported authentication currency. However, virtually any token-based system can be used as an auth framework for Astarte.

The main purpose of Astarte's design, however, is to keep things simple for everyone. Putting up a full-fledged SSO dedicated to Astarte is beyond the scope of this documentation, and we favor the use case where an existing SSO infrastructure is integrated with Astarte, rather than built ad-hoc.

For simple use cases and instant satisfaction, it is strongly advised to use a simpler solution, such as a dedicated OAuth server. Almost all popular languages and frameworks provide great projects which can spin up an OAuth2 server + user management in a matter of hours, from [Elixir/Phoenix](https://github.com/mustafaturan/shield) to [Java/Spring](https://github.com/spring-cloud-samples/authserver) to [Go](https://github.com/RichardKnop/go-oauth2-server).

[Astarte's Enterprise Distribution](https://astarte.cloud/enterprise) includes other add-ons, such as automation and configuration for popular SSOs.

## Best practices

Due to the nature of tokens, applications and SSOs must take care of emission and storage of the token themselves. In most production cases, Astarte will be part of a larger SSO infrastructure being one of the clients (this is especially true for OAuth).

Among best practices, emitting short-lived tokens should always be considered, but depending on the use case, the authentication pipeline can be further tuned to address a number of potential issues.

### Token exchange

OAuth, like other protocols supports the concept of a [Token Exchange](https://tools.ietf.org/html/draft-ietf-oauth-token-exchange-11). Consider a web dashboard with a logged in user. The user will, most likely, have a token which is used by its frontend to call upon the backend/APIs of the web dashboard.

For the sake of simplicity, one might include in this token the adequate claims to give the user access to Astarte, but this might not be desirable for a number of reasons outlined above. Token exchange, if supported by your SSO, provides a great way to work around this: whenever the backend or the frontend requires access to Astarte, it can invoke the token exchange mechanism of the SSO to generate a short lived token for the API call from the original authentication, which can then be used even as a single shot access mechanism.

### Granular claims

The token exchange approach can be efficiently paired with a mechanism of granular claims. Consider the use case above, and let's assume the frontend needs direct, frequent access to Astarte's APIs. Exchanging tokens too many times might put a burden on the SSO and might become impractical.

However, Astarte decouples entirely authentication and authorization - that means, if two subsequent (valid) tokens which represent the same identity have substantially different claims, it doesn't care. This is intentional, as it allows for a much more efficient pattern: the token used by an hypotetical frontend can have a subset of the user's claims - for example, allowing him to read data from its devices, whereas token exchange can be used whenever more specific operations should be performed - for example, sending some commands or data to devices.

This also addresses the objection that regular expressions can grow big or quite complicated in case users need a large number of very granular permissions. In such complex cases, the SSO can be tuned to give out only a subset of claims depending on the user's operation.

### Token revocation

Token revocation isn't natively supported in Astarte for two reason: the first one is performance, as keeping a revocation list is expensive in many regards. The second is the fact that the revocation list is, most of the time, SSO specific, and a dedicated SSO integration would be required.

Rather than token revocation, a better practice is to make sure every emitted token has a short enough lifetime. However, it is possible to extend Astarte's authorization stage to support revocation, even though there are no plans to provide upstream support for that.

### Changing a Realm's validation mean

Over the lifetime of a cluster, it might be necessary to change a realm's validation mean for the most diverse reasons. By design, validation means are meant to be long lived, and changing them is supposed to be an extraordinary operation.

Astarte supports only one validation mean at a time. When the validation mean is changed, all tokens emitted which could be validated with the previous mean become invalid.

It is also possible that there might be a delay between the request of a validation mean change and its actuation. This means during this grace period tokens will be validated against the previously configured mean. As such, it is advised to treat a validation mean change as a maintenance operation for the realm. More details can be found in the Administrator Guide.
