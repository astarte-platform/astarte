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

defmodule Astarte.Housekeeping.BackendSupervisor do
  use Supervisor
  require Logger

  alias Astarte.RPC.Protocol.Housekeeping, as: Protocol
  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.RPC.Handler

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("BackendSupervisor init", tag: "housekeeping_backend_sup_init")

    xandra_options =
      Config.xandra_options!()
      |> Keyword.put(:name, :xandra)

    children = [
      {Xandra.Cluster, xandra_options},
      {Astarte.RPC.AMQP.Server, [amqp_queue: Protocol.amqp_queue(), handler: Handler]}
    ]

    opts = [strategy: :rest_for_one, name: __MODULE__]
    Supervisor.init(children, opts)
  end
end
