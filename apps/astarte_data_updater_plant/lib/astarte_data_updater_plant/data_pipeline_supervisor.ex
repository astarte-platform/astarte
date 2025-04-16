#
# This file is part of Astarte.
#
# Copyright 2020 - 2025 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.DataPipelineSupervisor do
  use Supervisor

  alias Astarte.DataUpdaterPlant.ConsumersSupervisor
  alias Astarte.DataUpdaterPlant.AMQPEventsProducer
  alias Astarte.DataUpdaterPlant.Config

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Horde.Registry, [keys: :unique, name: Registry.MessageTracker, members: :auto]},
      {Horde.Registry, [keys: :unique, name: Registry.DataUpdater, members: :auto]},
      {Horde.Registry, [keys: :unique, name: Registry.DataUpdaterRPC, members: :auto]},
      {Horde.Registry, [keys: :unique, name: Registry.AMQPDataConsumer, members: :auto]},
      {Horde.Registry, [keys: :unique, name: Registry.VMQPluginRPC, members: :auto]},
      {Horde.DynamicSupervisor,
       [
         name: Supervisor.MessageTracker,
         strategy: :one_for_one,
         restart: :transient,
         members: :auto,
         distribution_strategy: Horde.UniformDistribution
       ]},
      {Horde.DynamicSupervisor,
       [
         name: Supervisor.DataUpdater,
         strategy: :one_for_one,
         restart: :transient,
         members: :auto,
         distribution_strategy: Horde.UniformDistribution
       ]},
      {ExRabbitPool.PoolSupervisor,
       rabbitmq_config: Config.amqp_producer_options!(),
       connection_pools: [Config.events_producer_pool_config!()]},
      AMQPEventsProducer,
      ConsumersSupervisor,
      Astarte.DataUpdaterPlant.RPC.Supervisor
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
