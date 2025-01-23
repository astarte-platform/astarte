# Copyright 2017-2023 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# General application configuration
config :astarte_appengine_api, namespace: Astarte.AppEngine.API

# Configures the endpoint
config :astarte_appengine_api, Astarte.AppEngine.APIWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "oLTSqHyMVoBtu3Gu504Dn6HFN1qdFXtkJ0yFViRDbXckOHgTjFs1XaRS0QaKZ8KL",
  render_errors: [view: Astarte.AppEngine.APIWeb.ErrorView, accepts: ~w(json)],
  check_origin: false,
  pubsub_server: Astarte.AppEngine.API.PubSub

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

# Disable phoenix logger since we're using PlugLoggerWithMeta
config :phoenix, :logger, false

# Enable Swagger by default (if we're here, we're not on distillery)
config :astarte_appengine_api, swagger_ui: true

config :astarte_appengine_api, :max_results_limit, 10000

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
