import Config

config :astarte_rpc, :amqp_connection, host: System.get_env("RABBITMQ_HOST") || "rabbitmq"

config :astarte_data_updater_plant, :amqp_consumer_options,
  host: System.get_env("RABBITMQ_HOST") || "rabbitmq"

config :logger, :console,
  format: {PrettyLog.UserFriendlyFormatter, :format},
  metadata: [:realm, :device_id, :function]

config :astarte_data_updater_plant, :astarte_instance_id, "test"
config :astarte_data_updater_plant, :rpc_client, MockRPCClient

config :astarte_data_updater_plant, :amqp_data_queue_total_count, 1
config :astarte_data_updater_plant, :amqp_data_queue_range_end, 0
config :astarte_data_updater_plant, :amqp_data_queue_range_start, 0
