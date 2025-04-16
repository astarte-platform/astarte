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

  alias Astarte.DataUpdaterPlant.DataUpdater

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
  def handle_call({:install_volatile_trigger, volatile_trigger}, from, state) do
    %{
      realm_name: realm,
      device_id: device_id,
      object_id: object_id,
      object_type: object_type,
      parent_id: parent_id,
      simple_trigger_id: trigger_id,
      simple_trigger: simple_trigger,
      trigger_target: trigger_target
    } = volatile_trigger

    with :ok <- DataUpdater.verify_device_exists(realm, device_id),
         {:ok, message_tracker} <- DataUpdater.fetch_message_tracker(realm, device_id),
         {:ok, dup} <- DataUpdater.fetch_data_updater_process(realm, device_id, message_tracker) do
      reply =
        GenServer.call(
          dup,
          {:handle_install_volatile_trigger, object_id, object_type, parent_id, trigger_id,
           simple_trigger, trigger_target}
        )

      {:reply, reply, state}
    else
      {:error, error} ->
        _ =
          Logger.error(
            "Error #{inspect(error)} while handling an `install_volatile_trigger` request, returning the error to the caller: #{inspect(from)}"
          )

        {:reply, {:error, error}, state}
    end
  end

  @impl GenServer
  def handle_call({:delete_volatile_trigger, delete_request}, from, state) do
    %{
      realm_name: realm,
      device_id: device_id,
      trigger_id: trigger_id
    } = delete_request

    with :ok <- DataUpdater.verify_device_exists(realm, device_id),
         {:ok, message_tracker} <- DataUpdater.fetch_message_tracker(realm, device_id),
         {:ok, dup} <- DataUpdater.fetch_data_updater_process(realm, device_id, message_tracker) do
      reply = GenServer.call(dup, {:handle_delete_volatile_trigger, trigger_id})

      {:reply, reply, state}
    else
      {:error, error} ->
        _ =
          Logger.error(
            "Error #{inspect(error)} while handling an `delete_volatile_trigger` request, returning the error to the caller: #{inspect(from)}"
          )

        {:reply, {:error, error}, state}
    end
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
end
