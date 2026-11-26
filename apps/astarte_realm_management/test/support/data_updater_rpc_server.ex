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

defmodule Astarte.RealmManagement.Test.DataUpdaterRPCServer do
  @moduledoc false

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok,
      name: {:via, Horde.Registry, {Registry.DataUpdaterRPC, :server}}
    )
  end

  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:interface_installed, {_realm, _name, _major}}, _from, state) do
    # Forward the message to any process that might be interested, or just ignore
    # For interfaces_test.exs, we could send it to a local process if we knew it.
    # We will handle assertions by relying on Phoenix.PubSub if needed,
    # or by not testing the RPC call here.
    {:reply, :ok, state}
  end

  def handle_call(_, _from, state), do: {:reply, :ok, state}
end
