#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.RealmManagement.RPC.Server do
  @moduledoc """
  Singleton for receiving messages across replicas.
  Messages sent here will be received by a single replica.
  """

  use GenServer, restart: :transient

  alias Astarte.RealmManagement.Devices
  alias Astarte.RealmManagement.RPC.Server
  alias Astarte.RPC.RealmManagement
  alias Astarte.RPC.RealmManagement.DeviceDeletion

  require Logger

  def start_link(init_arg) do
    opts = [name: RealmManagement.server_name()]

    with {:error, {:already_started, pid}} <- GenServer.start_link(Server, init_arg, opts) do
      {:ok, pid}
    end
  end

  @impl GenServer
  def init(_init_arg) do
    Process.flag(:trap_exit, true)
    {:ok, nil}
  end

  @impl GenServer
  def handle_call(%DeviceDeletion{} = request, _from, state) do
    %DeviceDeletion{encoded_device_id: encoded_device_id, realm_name: realm_name} = request
    result = Devices.delete_device(realm_name, encoded_device_id)

    {:reply, result, state}
  end

  @impl GenServer
  def handle_info(
        {:EXIT, _pid, {:name_conflict, {_name, _value}, _registry, _winning_pid}},
        state
      ) do
    "Received a :name_conflict signal from the outer space, maybe a netsplit occurred? Gracefully shutting down."
    |> Logger.warning(tag: "RPC exit")

    {:stop, :shutdown, state}
  end

  @impl GenServer
  def handle_info({:EXIT, _pid, :shutdown}, state) do
    "Received a :shutdown signal from the outer space, maybe the supervisor is mad? Gracefully shutting down."
    |> Logger.warning(tag: "RPC exit")

    {:stop, :shutdown, state}
  end
end
