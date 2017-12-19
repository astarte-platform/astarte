# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :astarte_rpc, :amqp_queue,
  "housekeeping_rpc"

import_config "#{Mix.env}.exs"
