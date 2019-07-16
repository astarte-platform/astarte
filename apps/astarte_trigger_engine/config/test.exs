use Mix.Config

config :cqerl,
  cassandra_nodes: [
    {System.get_env("CASSANDRA_DB_HOST") || "cassandra",
     System.get_env("CASSANDRA_DB_PORT") || 9042}
  ]

config :astarte_trigger_engine, :amqp_consumer_options,
  host: System.get_env("RABBITMQ_HOST") || "rabbitmq"

config :astarte_trigger_engine, :events_consumer, MockEventsConsumer
