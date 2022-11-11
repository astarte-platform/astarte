#
# This file is part of Astarte.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Astarte.TriggerEngine.ConsumerSupervisor do
  # Automatically defines child_spec/1
  use Supervisor
  require Logger
  alias Astarte.TriggerEngine.Config

  alias Astarte.TriggerEngine.AMQPConsumer.{AMQPConsumerSupervisor, AMQPConsumerTracker}

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    # make amqp supervisors logs less verbose
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    _ = Logger.info("Starting consumer supervisor", tag: "consumer_supervisor_start")

    children = [
      AMQPConsumerSupervisor,
      {Registry, [keys: :unique, name: Registry.AMQPConsumerRegistry]},
      {ExRabbitPool.PoolSupervisor,
       rabbitmq_config: Config.amqp_consumer_options!(),
       connection_pools: [Config.events_consumer_pool_config!()]},
      AMQPConsumerTracker
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
