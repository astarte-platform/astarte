use Mix.Config

config :astarte_rpc, :amqp_connection, host: System.get_env("RABBITMQ_HOST") || "rabbitmq"

config :cqerl,
  cassandra_nodes: [
    {System.get_env("CASSANDRA_DB_HOST") || "cassandra",
     System.get_env("CASSANDRA_DB_PORT") || 9042}
  ]

config :astarte_data_updater_plant, :amqp_consumer_options,
  host: System.get_env("RABBITMQ_HOST") || "rabbitmq"

config :logger, :console,
  format: {PrettyLog.UserFriendlyFormatter, :format},
  metadata: [:realm, :device_id, :function]
