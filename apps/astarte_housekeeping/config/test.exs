use Mix.Config

config :cqerl,
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST") || "cassandra", System.get_env("CASSANDRA_DB_PORT") || 9042}]

config :astarte_rpc, :amqp_connection,
  host: System.get_env("RABBITMQ_HOST") || "rabbitmq"
