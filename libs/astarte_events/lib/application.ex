#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Events.Application do
  use Application
  alias Astarte.Events.AMQPEventsProducer
  alias Astarte.Events.AMQPTriggers.VHostSupervisor
  alias Astarte.Events.Config

  def start(_type, _args) do
    events_pool =
      Supervisor.child_spec(
        {ExRabbitPool.PoolSupervisor,
         rabbitmq_config: Config.amqp_options!(), connection_pools: [Config.events_pool_config!()]},
        id: :events_producer_pool
      )

    children = [
      events_pool,
      AMQPEventsProducer,
      {Registry, keys: :unique, name: Astarte.Events.AMQPTriggers.Registry},
      VHostSupervisor
    ]

    opts = [strategy: :rest_for_one, name: Astarte.Events.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
