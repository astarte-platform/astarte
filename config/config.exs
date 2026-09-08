import Config

# General application configuration
config :astarte_appengine_api, namespace: Astarte.AppEngine.API

config :astarte_appengine_api, ecto_repos: [Astarte.DataAccess.Repo]

# Configures the endpoint
config :astarte_appengine_api, Astarte.AppEngine.APIWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  secret_key_base: "oLTSqHyMVoBtu3Gu504Dn6HFN1qdFXtkJ0yFViRDbXckOHgTjFs1XaRS0QaKZ8KL",
  render_errors: [view: Astarte.AppEngine.APIWeb.ErrorView, accepts: ~w(json)],
  check_origin: false,
  pubsub_server: Astarte.AppEngine.API.PubSub

config :logger, level: :debug

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [
    :method,
    :request_path,
    :status_code,
    :elapsed,
    :realm,
    :group_name,
    :device_alias,
    :device_id,
    :interface,
    :path,
    :module,
    :function,
    :request_id,
    :tag,
    :datacenter,
    :replication_factor,
    :hw_id,
    :common_name
  ]

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

# Disable phoenix logger since we're using PlugLoggerWithMeta
config :phoenix, :logger, false

# Enable Swagger by default (if we're here, we're not on distillery)
config :astarte_appengine_api, swagger_ui: true

config :astarte_appengine_api, :max_results_limit, 10000

config :astarte_trigger_engine, :amqp_consumer_options,
  host: "localhost",
  username: "guest",
  password: "guest",
  virtual_host: "/",
  port: 5672

config :astarte_trigger_engine, :amqp_events_exchange_name, "astarte_events"
config :astarte_trigger_engine, :amqp_events_queue_name, "astarte_events"
config :astarte_trigger_engine, :amqp_events_routing_key, "trigger_engine"
config :astarte_trigger_engine, :events_consumer, Astarte.TriggerEngine.EventsConsumer
config :astarte_trigger_engine, ecto_repos: [Astarte.DataAccess.Repo]

config :astarte_housekeeping,
  ecto_repos: [Astarte.DataAccess.Repo],
  namespace: Astarte.Housekeeping

config :astarte_housekeeping, Astarte.DataAccess.Repo,
  migration_primary_key: [name: :id, type: :integer]

config :astarte_housekeeping, Astarte.HousekeepingWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  secret_key_base: "Nxme5JSsvLykfa6sSoC+7cy9f3ycI8No2T1pwqFpB47KAt6tK/61jGpB+TIhNdjl",
  render_errors: [view: Astarte.HousekeepingWeb.ErrorView, accepts: ~w(json)]

config :astarte_housekeeping, Astarte.HousekeepingWeb.AuthGuardian,
  allowed_algos: ["ES256", "ES384", "ES512", "PS256", "PS384", "PS512", "RS256", "RS384", "RS512"]

config :astarte_pairing,
  namespace: Astarte.Pairing

config :astarte_pairing, Astarte.PairingWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  secret_key_base: "LXWGqSIaFRDtOaX5Qgfw5TrSAsWQs6V8OkXEsGuuqRhc1oFvrGax/SfP7F7gAIcX",
  render_errors: [view: Astarte.PairingWeb.ErrorView, accepts: ~w(json)]

# FDO session tokens use the endpoint's secret_key_base
config :astarte_fdo, :endpoint, Astarte.PairingWeb.Endpoint

config :astarte_pairing, Astarte.PairingWeb.AuthGuardian,
  allowed_algos: ["ES256", "ES384", "ES512", "PS256", "PS384", "PS512", "RS256", "RS384", "RS512"]

config :mime, :types, %{
  "application/cbor" => ["cbor"]
}

import_config "#{config_env()}.exs"
