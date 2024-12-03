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
config :astarte_housekeeping_api,
  namespace: Astarte.Housekeeping.API

# Configures the endpoint
config :astarte_housekeeping_api, Astarte.Housekeeping.APIWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Nxme5JSsvLykfa6sSoC+7cy9f3ycI8No2T1pwqFpB47KAt6tK/61jGpB+TIhNdjl",
  render_errors: [view: Astarte.Housekeeping.APIWeb.ErrorView, accepts: ~w(json)]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :astarte_housekeeping_api, Astarte.Housekeeping.APIWeb.AuthGuardian,
  allowed_algos: ["ES256", "ES384", "ES512", "PS256", "PS384", "PS512", "RS256", "RS384", "RS512"]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
