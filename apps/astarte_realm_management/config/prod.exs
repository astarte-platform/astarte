use Mix.Config

config :cqerl,
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST"), System.get_env("CASSANDRA_DB_PORT")}]

config :astarte_realm_management, :amqp_connection,
  username: "guest",
  password: "guest",
  host: "localhost",
  virtual_host: "/",
  port: 5672

config :astarte_realm_management, :rpc_queue,
  "realm_management_rpc"
