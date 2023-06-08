#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

# lager is used by rabbit_common.
# Silent it by setting the higher loglevel.
config :lager,
  error_logger_redirect: false,
  handlers: [level: :critical]

config :astarte_trigger_engine, :amqp_consumer_options,
  host: "localhost",
  username: "guest",
  password: "guest",
  virtual_host: "/",
  port: 5672

config :astarte_trigger_engine, :amqp_events_queue_name, "astarte_events"

config :astarte_trigger_engine, :amqp_events_exchange_name, "astarte_events"

config :astarte_trigger_engine, :amqp_events_routing_key, "trigger_engine"

config :astarte_trigger_engine, :events_consumer, Astarte.TriggerEngine.EventsConsumer

config :astarte_trigger_engine, :amqp_adapter, ExRabbitPool.RabbitMQ

import_config "#{config_env()}.exs"
