use Mix.Config

config :astarte_pairing, :amqp_connection,
  username: "guest",
  password: "guest",
  host: "localhost",
  virtual_host: "/",
  port: 5672

config :astarte_pairing, :rpc_queue,
  "pairing_rpc"
