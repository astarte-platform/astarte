#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Server do
  use GenServer
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.DataUpdater.Core

  require Logger

  def start_link({realm, device_id, _message_tracker} = args),
    do: start_link(realm, device_id, args)

  def start_link({realm, device_id, _message_tracker, :wait_start} = args),
    do: start_link(realm, device_id, args)

  defp start_link(realm, device_id, args) do
    name = {:via, Horde.Registry, {Registry.DataUpdater, {realm, device_id}}}
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @impl GenServer
  def init({realm, device_id, message_tracker}) do
    timeout = Config.data_updater_deactivation_interval_ms!()

    Process.flag(:trap_exit, true)

    {:ok, Impl.init_state(realm, device_id, message_tracker), timeout}
  end

  @impl GenServer
  def init({realm, device_id, message_tracker, :wait_start}) do
    timeout = Config.data_updater_deactivation_interval_ms!()

    Process.flag(:trap_exit, true)
    {:ok, {realm, device_id, message_tracker}, timeout}
  end

  @impl GenServer
  def handle_cast({:handle_connection, ip_address, message_id, timestamp}, state) do
    timeout = Config.data_updater_deactivation_interval_ms!()

    if MessageTracker.can_process_message(state.message_tracker, message_id) do
      new_state = Impl.handle_connection(state, ip_address, message_id, timestamp)
      {:noreply, new_state, timeout}
    else
      {:noreply, state, timeout}
    end
  end

  @impl GenServer
  def handle_cast({:handle_disconnection, message_id, timestamp}, state) do
    timeout = Config.data_updater_deactivation_interval_ms!()

    if MessageTracker.can_process_message(state.message_tracker, message_id) do
      new_state = Impl.handle_disconnection(state, message_id, timestamp)
      {:noreply, new_state, timeout}
    else
      {:noreply, state, timeout}
    end
  end

  # TODO remove this when all heartbeats will be moved to internal
  @impl GenServer
  def handle_cast({:handle_heartbeat, message_id, timestamp}, state) do
    if MessageTracker.can_process_message(state.message_tracker, message_id) do
      new_state = Core.HeartbeatHandler.handle_heartbeat(state, message_id, timestamp)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:handle_internal, payload, path, message_id, timestamp}, state) do
    if MessageTracker.can_process_message(state.message_tracker, message_id) do
      case Impl.handle_internal(state, payload, path, message_id, timestamp) do
        {:continue, new_state} -> {:noreply, new_state}
        # No more messages from this device, time out now in order to stop this process
        {:stop, new_state} -> {:noreply, new_state, 0}
      end
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:handle_data, interface, path, payload, message_id, timestamp}, state) do
    timeout = Config.data_updater_deactivation_interval_ms!()

    if MessageTracker.can_process_message(state.message_tracker, message_id) do
      start = System.monotonic_time()

      new_state = Impl.handle_data(state, interface, path, payload, message_id, timestamp)

      :telemetry.execute(
        [:astarte, :data_updater_plant, :data_updater, :handle_data],
        %{duration: System.monotonic_time() - start},
        %{realm: state.realm}
      )

      {:noreply, new_state, timeout}
    else
      {:noreply, state, timeout}
    end
  end

  @impl GenServer
  def handle_cast({:handle_introspection, payload, message_id, timestamp}, state) do
    timeout = Config.data_updater_deactivation_interval_ms!()

    if MessageTracker.can_process_message(state.message_tracker, message_id) do
      new_state = Impl.handle_introspection(state, payload, message_id, timestamp)
      {:noreply, new_state, timeout}
    else
      {:noreply, state, timeout}
    end
  end

  @impl GenServer
  def handle_cast({:handle_control, payload, path, message_id, timestamp}, state) do
    timeout = Config.data_updater_deactivation_interval_ms!()

    if MessageTracker.can_process_message(state.message_tracker, message_id) do
      new_state = Impl.handle_control(state, payload, path, message_id, timestamp)
      {:noreply, new_state}
    else
      {:noreply, state, timeout}
    end
  end

  @impl GenServer
  def handle_call(
        {:handle_install_volatile_trigger, object_id, object_type, parent_id, trigger_id,
         simple_trigger, trigger_target},
        _from,
        state
      ) do
    timeout = Config.data_updater_deactivation_interval_ms!()

    {return_value, new_state} =
      Core.Trigger.handle_install_volatile_trigger(
        state,
        object_id,
        object_type,
        parent_id,
        trigger_id,
        simple_trigger,
        trigger_target
      )

    {:reply, return_value, new_state, timeout}
  end

  def handle_call(:start, _from, {realm, device_id, message_tracker}) do
    timeout = Config.data_updater_deactivation_interval_ms!()
    state = Impl.init_state(realm, device_id, message_tracker)

    {:reply, :ok, state, timeout}
  end

  @impl GenServer
  def handle_call({:handle_delete_volatile_trigger, trigger_id}, _from, state) do
    timeout = Config.data_updater_deactivation_interval_ms!()

    {result, new_state} = Core.Trigger.handle_delete_volatile_trigger(state, trigger_id)

    {:reply, result, new_state, timeout}
  end

  @impl GenServer
  def handle_call({:dump_state}, _from, state) do
    timeout = Config.data_updater_deactivation_interval_ms!()

    {:reply, state, state, timeout}
  end

  @impl GenServer
  def handle_call({:start_device_deletion, timestamp}, _from, state) do
    {result, new_state} = Impl.start_device_deletion(state, timestamp)
    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_info({:DOWN, _, :process, pid, :normal}, %{message_tracker: pid} = state) do
    # This is a MessageTracker normally terminating due to deactivation
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _, :process, _pid, :shutdown}, state) do
    {:stop, :shutdown, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    {:stop, :monitored_process_died, state}
  end

  @impl GenServer
  def handle_info(
        {:EXIT, _pid, {:name_conflict, {_name, _value}, _registry, _winning_pid}},
        state
      ) do
    _ =
      Logger.warning(
        "Received a :name_confict signal from the outer space, maybe a netsplit occurred? Gracefully shutting down.",
        tag: "name_conflict"
      )

    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    :ok = Impl.handle_deactivation(state)
    :ok = MessageTracker.deactivate(state.message_tracker)

    {:stop, :normal, state}
  end
end
