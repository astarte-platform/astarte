# Astarte Auth

Authentication and authorization code shared by every Astarte service:

- `Astarte.Auth.OpenFGA` — relationship checks against the cluster's OpenFGA server.
- `Astarte.Auth.GraphQL.Middleware.AuthorizeFGA` — Absinthe middleware that authorizes field
  resolution through those checks.
- `Astarte.Auth.GraphQL.Plug.Context` — plug that verifies the request's JWT with the service's
  own Guardian implementation and builds the Absinthe context the middleware reads.

OpenFGA is a single cluster-wide service, so its URL and store id are configured once, in this
library (`Astarte.Auth.Config`), rather than per service. The store itself is provisioned
out-of-band by the OpenFGA init container.
