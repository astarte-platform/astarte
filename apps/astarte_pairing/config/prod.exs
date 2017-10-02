use Mix.Config

config :astarte_pairing, :amqp_connection,
  username: "guest",
  password: "guest",
  host: "localhost",
  virtual_host: "/",
  port: 5672

config :astarte_pairing, :rpc_queue,
  "pairing_rpc"

config :astarte_pairing, :broker_url,
  "ssl://broker.beta.astarte.cloud:8883/"
