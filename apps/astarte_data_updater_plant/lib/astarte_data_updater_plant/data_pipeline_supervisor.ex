#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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
  alias Astarte.DataUpdaterPlant.RPC.Handler
  alias Astarte.DataUpdaterPlant.Config

  alias Astarte.RPC.Protocol.DataUpdaterPlant, as: Protocol

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, [keys: :unique, name: Registry.MessageTracker]},
      {Registry, [keys: :unique, name: Registry.DataUpdater]},
      {ExRabbitPool.PoolSupervisor,
       rabbitmq_config: Config.amqp_producer_options!(),
       connection_pools: [Config.events_producer_pool_config!()]},
      AMQPEventsProducer,
      ConsumersSupervisor,
      {Astarte.RPC.AMQP.Server, [amqp_queue: Protocol.amqp_queue(), handler: Handler]},
      Astarte.RPC.AMQP.Client
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
