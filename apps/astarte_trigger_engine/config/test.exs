use Mix.Config

config :astarte_trigger_engine, :amqp_consumer_options,
  host: System.get_env("RABBITMQ_HOST") || "rabbitmq"
