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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.ProducersSupervisor do
  @moduledoc """
  Supervisor for AMQP producers.
  """

  use Supervisor
  require Logger

  alias Astarte.DataUpdaterPlant.AMQPEventsProducer
  alias Astarte.DataUpdaterPlant.Config

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_init_arg) do
    Logger.info("AMQPDataProducer supervisor init.", tag: "data_producer_sup_init")

    children = [
      {ExRabbitPool.PoolSupervisor,
       rabbitmq_config: Config.amqp_producer_options!(),
       connection_pools: [Config.events_producer_pool_config!()]},
      AMQPEventsProducer
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
