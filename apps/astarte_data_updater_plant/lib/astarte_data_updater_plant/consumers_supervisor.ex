#
# This file is part of Astarte.
#
# Copyright 2019 - 2023 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.ConsumersSupervisor do
  use Supervisor
  require Logger

  alias Astarte.DataUpdaterPlant.AMQPDataConsumer
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataUpdater.DeletionScheduler

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("AMQPDataConsumer supervisor init.", tag: "data_consumer_sup_init")

    children = [
      {Registry, [keys: :unique, name: Registry.AMQPDataConsumer]},
      {AMQPDataConsumer.ConnectionManager, amqp_opts: Config.amqp_consumer_options!()},
      AMQPDataConsumer.Supervisor,
      DeletionScheduler
    ]

    opts = [strategy: :rest_for_one, name: __MODULE__]

    Supervisor.init(children, opts)
  end
end
