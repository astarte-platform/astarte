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

defmodule Astarte.Events.AMQPEvents.Supervisor do
  use Supervisor

  alias Astarte.Events.AMQPEvents.Producer
  alias Astarte.Events.Config

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_init_arg) do
    events_pool =
      Supervisor.child_spec(
        {ExRabbitPool.PoolSupervisor,
         rabbitmq_config: Config.amqp_options!(), connection_pools: [Config.events_pool_config!()]},
        id: :events_producer_pool
      )

    [
      events_pool,
      Producer
    ]
    |> Supervisor.init(strategy: :rest_for_one)
  end
end
