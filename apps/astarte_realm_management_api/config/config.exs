# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :astarte_realm_management_api,
  namespace: Astarte.RealmManagement.API

# Configures the endpoint
config :astarte_realm_management_api, Astarte.RealmManagement.APIWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "CixkA/Dn3ya0rSp9nV0ZkvE0qEaSp2cKH/hzp5LiPK9iEGjX6S92b8fDrnfgCS5Y",
  render_errors: [view: Astarte.RealmManagement.APIWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: Astarte.RealmManagement.API.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :astarte_rpc, :amqp_queue,
  "realm_management_rpc"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
