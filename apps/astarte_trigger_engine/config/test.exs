import Config

config :astarte_trigger_engine, :amqp_consumer_options,
  host: System.get_env("RABBITMQ_HOST") || "rabbitmq"

config :astarte_trigger_engine, :events_consumer, MockEventsConsumer
config :astarte_trigger_engine, :astarte_instance_id, "test"

config :logger, :console,
  format: {PrettyLog.UserFriendlyFormatter, :format},
  metadata: [:function]
