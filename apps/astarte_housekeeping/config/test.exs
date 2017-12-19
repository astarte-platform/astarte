use Mix.Config

config :cqerl, 
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST") || "scylladb-scylla", System.get_env("CASSANDRA_DB_PORT") || 9042}]

config :astarte_rpc, :amqp_connection,
  host: "rabbitmq"
