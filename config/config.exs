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
    :tag
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

config :astarte_trigger_engine, :events_consumer, Astarte.TriggerEngine.EventsConsumer

import_config "#{config_env()}.exs"
