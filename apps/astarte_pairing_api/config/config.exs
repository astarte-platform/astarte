#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
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
  pubsub: [name: Astarte.Pairing.API.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :astarte_rpc, :amqp_queue,
  "pairing_rpc"

config :astarte_pairing_api, Astarte.Pairing.APIWeb.AgentGuardian,
  allowed_algos: ["RS256"],
  secret_key: {Astarte.Pairing.API.Config, :jwt_public_key, []}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
