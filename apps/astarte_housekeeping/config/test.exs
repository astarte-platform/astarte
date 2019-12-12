use Mix.Config

config :astarte_data_access,
       :cassandra_nodes,
       System.get_env("ASTARTE_CASSANDRA_NODES") || "cassandra"

config :astarte_rpc, :amqp_connection, host: System.get_env("RABBITMQ_HOST") || "rabbitmq"

config :logger, :console,
  format: {PrettyLog.UserFriendlyFormatter, :format},
  metadata: [:realm, :function]
