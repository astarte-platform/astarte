use Mix.Config

config :cqerl, 
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST") || "scylladb-scylla", System.get_env("CASSANDRA_DB_PORT") || 9042}]

config :astarte_housekeeping, :amqp_connection,
  username: "guest",
  password: "guest",
  hostname: "rabbitmq",
  virtual_host: "/",
  port: 5672

config :astarte_housekeeping, :amqp_consumer,
  queue: "housekeeping_rpc",
  callback: &Housekeeping.Engine.process_rpc/1
