use Mix.Config

config :astarte_pairing, :amqp_connection,
  username: "guest",
  password: "guest",
  host: "rabbitmq",
  virtual_host: "/",
  port: 5672

config :astarte_pairing, :rpc_queue,
  "pairing_rpc"

config :astarte_pairing, :broker_url,
  "ssl://broker.beta.astarte.cloud:8883/"

config :astarte_pairing, :cfssl_url,
  System.get_env("CFSSL_API_URL") || "http://laslabs-alpine-cfssl:8080"

config :cqerl, :cassandra_nodes,
  [{System.get_env("CASSANDRA_DB_HOST") || "scylladb-scylla", System.get_env("CASSANDRA_DB_PORT") || 9042}]
