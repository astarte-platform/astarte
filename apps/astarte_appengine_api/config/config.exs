# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :astarte_appengine_api,
  namespace: AstarteAppengineApi

# Configures the endpoint
config :astarte_appengine_api, AstarteAppengineApiWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "oLTSqHyMVoBtu3Gu504Dn6HFN1qdFXtkJ0yFViRDbXckOHgTjFs1XaRS0QaKZ8KL",
  render_errors: [view: AstarteAppengineApiWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: AstarteAppengineApi.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
