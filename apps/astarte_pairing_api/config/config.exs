# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :astarte_pairing_api,
  namespace: Astarte.Pairing.API

# Configures the endpoint
config :astarte_pairing_api, Astarte.Pairing.APIWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "LXWGqSIaFRDtOaX5Qgfw5TrSAsWQs6V8OkXEsGuuqRhc1oFvrGax/SfP7F7gAIcX",
  render_errors: [view: Astarte.Pairing.APIWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: Astarte.Pairing.API.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :astarte_pairing_api, :rpc_queue,
  "pairing_rpc"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
