use Mix.Config

config :cqerl, 
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST") || "scylladb-scylla", System.get_env("CASSANDRA_DB_PORT") || 9042}]

config :astarte_housekeeping, :amqp_connection,
  username: "guest",
  password: "guest",
  host: "rabbitmq",
  virtual_host: "/",
  port: 5672

config :astarte_housekeeping, :rpc_queue,
  "housekeeping_rpc"
