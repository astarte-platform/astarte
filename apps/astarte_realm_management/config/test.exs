import Config

config :astarte_rpc, :amqp_connection, host: System.get_env("RABBITMQ_HOST") || "rabbitmq"
config :astarte_realm_management, :astarte_instance_id, "test"

config :logger, :console,
  format: {PrettyLog.UserFriendlyFormatter, :format},
  metadata: [
    :realm,
    :function,
    :tag
  ]
