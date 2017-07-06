# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :astarte_housekeeping_api,
  namespace: Astarte.Housekeeping.API

# Configures the endpoint
config :astarte_housekeeping_api, Astarte.Housekeeping.API.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Nxme5JSsvLykfa6sSoC+7cy9f3ycI8No2T1pwqFpB47KAt6tK/61jGpB+TIhNdjl",
  render_errors: [view: Astarte.Housekeeping.API.Web.ErrorView, accepts: ~w(json)],
  pubsub: [name: Astarte.Housekeeping.API.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
