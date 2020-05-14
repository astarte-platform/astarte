#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.DataUpdaterPlant.AMQPDataConsumer.Supervisor do
  use Supervisor

  alias Astarte.DataUpdaterPlant.AMQPDataConsumer
  alias Astarte.DataUpdaterPlant.Config

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    queue_range_start = Config.data_queue_range_start()
    queue_range_end = Config.data_queue_range_end()

    children = amqp_data_consumers_childspecs(queue_range_start, queue_range_end)

    opts = [strategy: :one_for_one, name: __MODULE__]

    Supervisor.init(children, opts)
  end

  defp amqp_data_consumers_childspecs(queue_range_start, queue_range_end) do
    queue_prefix = Config.data_queue_prefix()

    for queue_index <- queue_range_start..queue_range_end do
      queue_name = "#{queue_prefix}#{queue_index}"
      args = [queue_name: queue_name, queue_index: queue_index]
      Supervisor.child_spec({AMQPDataConsumer, args}, id: {AMQPDataConsumer, queue_index})
    end
  end
end
