import Config

config :astarte_rpc, :amqp_connection, host: System.get_env("RABBITMQ_HOST") || "rabbitmq"

config :astarte_data_updater_plant, :amqp_consumer_options,
  host: System.get_env("RABBITMQ_HOST") || "rabbitmq"

config :logger, :console,
  format: {PrettyLog.UserFriendlyFormatter, :format},
  metadata: [:realm, :device_id, :function]

config :astarte_data_updater_plant, :rpc_client, MockRPCClient
