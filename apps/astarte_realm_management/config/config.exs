# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# General application configuration
config :astarte_realm_management, namespace: Astarte.RealmManagement

# Configures the endpoint
config :astarte_realm_management, Astarte.RealmManagementWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "CixkA/Dn3ya0rSp9nV0ZkvE0qEaSp2cKH/hzp5LiPK9iEGjX6S92b8fDrnfgCS5Y",
  render_errors: [view: Astarte.RealmManagementWeb.ErrorView, accepts: ~w(json)]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :astarte_realm_management, Astarte.RealmManagementWeb.AuthGuardian,
  allowed_algos: ["ES256", "ES384", "ES512", "PS256", "PS384", "PS512", "RS256", "RS384", "RS512"]

config :phoenix, :json_library, Jason

# Disable phoenix logger since we're using PlugLoggerWithMeta
config :phoenix, :logger, false

# TODO: add astarte_realm_management when available: it's needed to notify all realm_management
# replicas of trigger installation/deletions
config :astarte_rpc, :astarte_services, [:astarte_data_updater_plant, :astarte_realm_management]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
