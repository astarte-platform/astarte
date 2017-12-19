# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :astarte_pairing, :secret_key_base,
  "42WxT+9X+hKbTlv3n7cmzCrlzO2NpCVjRUlpfPYdWt627wetvY4il7Qpq6RRqeNk"

config :astarte_rpc, :amqp_queue,
  "pairing_rpc"

import_config "#{Mix.env}.exs"
