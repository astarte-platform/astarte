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

defmodule Astarte.DataUpdaterPlant.RPC.Server do
  @moduledoc """
  This server receives incoming calls from other astarte services and queues the
  calls to the appropriate dup services to handle the calls.
  """

  alias Astarte.DataUpdaterPlant.RPC.Server.Core

  use GenServer, restart: :transient
  require Logger

  def start_link(args, opts \\ []) do
    name = {:via, Horde.Registry, {Registry.DataUpdaterRPC, :server}}
    opts = Keyword.put(opts, :name, name)

    GenServer.start_link(__MODULE__, args, opts)
  end

  @impl GenServer
  def init(_args) do
    Process.flag(:trap_exit, true)
    {:ok, []}
  end

  @impl GenServer
  def handle_call({:install_volatile_trigger, volatile_trigger}, _from, state) do
    reply = Core.install_volatile_trigger(volatile_trigger)

    with {:error, error} <- reply do
      _ = Logger.warning("Error while intalling a new volatile trigger: #{inspect(error)}")
    end

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_call({:delete_volatile_trigger, delete_request}, _from, state) do
    reply = Core.delete_volatile_trigger(delete_request)

    with {:error, error} <- reply do
      _ = Logger.warning("Error while deleting a volatile trigger: #{inspect(error)}")
    end

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_info(
        {:EXIT, _pid, {:name_conflict, {_name, _value}, _registry, _winning_pid}},
        state
      ) do
    _ =
      Logger.warning(
        "Received a :name_confict signal from the outer space, maybe a netsplit occurred? Gracefully shutting down.",
        tag: "RPC exit"
      )

    {:stop, :shutdown, state}
  end

  @impl GenServer
  def handle_info({:EXIT, _pid, :shutdown}, state) do
    _ =
      Logger.warning(
        "Received a :shutdown signal from the outer space, maybe the supervisor is mad? Gracefully shutting down.",
        tag: "RPC exit"
      )

    {:stop, :shutdown, state}
  end

  @impl GenServer
  def handle_call({:install_persistent_triggers, triggers}, _from, state) do
    result = Core.install_persistent_triggers(triggers)
    {:reply, result, state}
  end
end
