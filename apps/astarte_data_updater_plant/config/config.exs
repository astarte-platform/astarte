# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

# lager is used by rabbit_common.
# Silent it by setting the higher loglevel.
config :lager,
  error_logger_redirect: false,
  handlers: [level: :critical]

config :astarte_data_updater_plant, :data_queue_prefix, "astarte_data_"

config :astarte_data_updater_plant, :amqp_consumer_options,
  host: "localhost",
  username: "guest",
  password: "guest",
  virtual_host: "/",
  port: 5672

config :astarte_data_updater_plant, :amqp_events_exchange_name, "astarte_events"

config :astarte_data_updater_plant, :amqp_consumer_prefetch_count, 300

config :astarte_rpc, :amqp_queue, "data_updater_plant_rpc"

config :astarte_data_updater_plant, :amqp_adapter, ExRabbitPool.RabbitMQ

import_config "#{config_env()}.exs"
