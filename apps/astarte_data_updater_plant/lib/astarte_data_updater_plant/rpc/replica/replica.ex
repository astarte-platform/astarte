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

defmodule Astarte.DataUpdaterPlant.RPC.Replica do
  use GenServer

  alias Astarte.DataUpdaterPlant.RPC.Replica.Core

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_init_arg) do
    case Horde.Registry.register(Registry.DataUpdaterRPC, {:replica, self()}, nil) do
      {:ok, _} -> {:ok, nil}
      {:error, _} -> {:error, :already_registered}
    end
  end

  @impl true
  def handle_call({:install_trigger, trigger_data}, _from, state) do
    {realm_name, tagged_simple_trigger, target, policy, data} = trigger_data
    reply = Core.install_trigger(realm_name, tagged_simple_trigger, target, policy, data)

    {:reply, reply, state}
  end

  def send_all_replicas(msg) do
    Core.multi_call(replicas(), msg)
    |> Core.handle_result()
  end

  defp replicas do
    Horde.Registry.select(
      Registry.DataUpdaterRPC,
      [{{{:replica, :"$1"}, :_, :_}, [], [:"$1"]}]
    )
  end
end
