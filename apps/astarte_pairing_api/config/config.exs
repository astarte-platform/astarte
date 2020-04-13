#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

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
  pubsub: [name: Astarte.Pairing.API.PubSub, adapter: Phoenix.PubSub.PG2],
  instrumenters: [Astarte.Pairing.APIWeb.Metrics.PhoenixInstrumenter]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# lager is used by rabbit_common.
# Silent it by setting the higher loglevel.
config :lager,
  error_logger_redirect: false,
  handlers: [level: :critical]

config :astarte_pairing_api, Astarte.Pairing.APIWeb.AuthGuardian,
  allowed_algos: ["ES256", "ES384", "ES512", "PS256", "PS384", "PS512", "RS256", "RS384", "RS512"]

config :phoenix, :json_library, Jason

config :prometheus, Astarte.Pairing.APIWeb.Metrics.PhoenixInstrumenter,
  controller_call_labels: [:controller, :action],
  duration_buckets: [
    10,
    25,
    50,
    100,
    250,
    500,
    1000,
    2500,
    5000,
    10_000,
    25_000,
    50_000,
    100_000,
    250_000,
    500_000,
    1_000_000,
    2_500_000,
    5_000_000,
    10_000_000
  ],
  registry: :default,
  duration_unit: :microseconds

config :prometheus, Astarte.Pairing.APIWeb.Metrics.PipelineInstrumenter,
  labels: [:status_class, :method, :host, :scheme],
  duration_buckets: [
    10,
    100,
    1_000,
    10_000,
    100_000,
    300_000,
    500_000,
    750_000,
    1_000_000,
    1_500_000,
    2_000_000,
    3_000_000
  ],
  registry: :default,
  duration_unit: :microseconds

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
