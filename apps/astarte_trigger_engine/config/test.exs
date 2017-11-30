use Mix.Config

config :cqerl,
  cassandra_nodes: [{System.get_env("CASSANDRA_DB_HOST") || "scylladb-scylla", System.get_env("CASSANDRA_DB_PORT") || 9042}]

config :astarte_trigger_engine, :amqp_consumer_options,
  host: System.get_env("RABBITMQ_HOST") || "rabbitmq"
