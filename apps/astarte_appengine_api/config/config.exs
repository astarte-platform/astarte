# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# lager is used by rabbit_common.
# Silent it by setting the higher loglevel.
config :lager, handlers: [level: :critical]

# General application configuration
config :astarte_appengine_api, namespace: Astarte.AppEngine.API

# Configures the endpoint
config :astarte_appengine_api, Astarte.AppEngine.APIWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "oLTSqHyMVoBtu3Gu504Dn6HFN1qdFXtkJ0yFViRDbXckOHgTjFs1XaRS0QaKZ8KL",
  render_errors: [view: Astarte.AppEngine.APIWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: Astarte.AppEngine.API.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :astarte_appengine_api, Astarte.AppEngine.APIWeb.AuthGuardian,
  allowed_algos: [
    "ES256",
    "ES384",
    "ES512",
    "PS256",
    "PS384",
    "PS512",
    "RS256",
    "RS384",
    "RS512"
  ]

config :astarte_appengine_api, Astarte.AppEngine.APIWeb.SocketGuardian,
  allowed_algos: [
    "ES256",
    "ES384",
    "ES512",
    "PS256",
    "PS384",
    "PS512",
    "RS256",
    "RS384",
    "RS512"
  ]

config :phoenix, :json_library, Jason

# Enable Swagger by default (if we're here, we're not on distillery)
config :astarte_appengine_api, swagger_ui: true

config :astarte_appengine_api, :max_results_limit, 10000

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
