# Astarte Auth

Authentication and authorization code shared by every Astarte service:

- `Astarte.Auth.OpenFGA` - relationship checks against the cluster's OpenFGA server.
- `Astarte.Auth.GraphQL.Middleware.AuthorizeFGA` - Absinthe middleware that authorizes field
  resolution through those checks.
- `Astarte.Auth.GraphQL.Plug.Context` - plug that builds the Absinthe context the middleware reads,
  from the identity the service's own Guardian plugs loaded.
- `Astarte.Auth.GraphQL.Plug.RequireRealmHeader` - plug that assigns the realm of a GraphQL
  request from its `astarte-realm` header, or ends the request with a GraphQL error.
- `Astarte.Auth.Plug.RequireRealmPathParam` - plug that assigns the realm of a REST request from
  its `realm_name` path parameter, or ends the request with a 401.
- `Astarte.Auth.Plug.FetchRealmName` - plug that assigns the realm a request refers to, from its
  path or its `astarte-realm` header.

OpenFGA is a single cluster-wide service, so its URL and store id are configured once, in this
library (`Astarte.Auth.Config`), rather than per service. The store itself is provisioned
out-of-band by the OpenFGA init container.

Outside compose, a service needs a reachable OpenFGA (`http://localhost:8081` in dev, or
`ASTARTE_OPENFGA_URL`) holding a store named `astarte`, or it won't start.
