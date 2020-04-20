#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl
  alias Astarte.DataUpdaterPlant.MessageTracker

  def start(realm, device_id, message_tracker, opts \\ []) do
    GenServer.start(__MODULE__, {realm, device_id, message_tracker}, opts)
  end

  def init({realm, device_id, message_tracker}) do
    send(self(), {:initialize, realm, device_id, message_tracker})
    {:ok, nil}
  end

  def handle_cast({:handle_connection, ip_address, message_id, timestamp}, state) do
    if MessageTracker.can_process_message(state.message_tracker, message_id) do
      new_state = Impl.handle_connection(state, ip_address, message_id, timestamp)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:handle_disconnection, message_id, timestamp}, state) do
    if MessageTracker.can_process_message(state.message_tracker, message_id) do
      new_state = Impl.handle_disconnection(state, message_id, timestamp)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:handle_heartbeat, message_id, timestamp}, state) do
    if MessageTracker.can_process_message(state.message_tracker, message_id) do
      new_state = Impl.handle_heartbeat(state, message_id, timestamp)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:handle_data, interface, path, payload, message_id, timestamp}, state) do
    if MessageTracker.can_process_message(state.message_tracker, message_id) do
      new_state = Impl.handle_data(state, interface, path, payload, message_id, timestamp)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:handle_introspection, payload, message_id, timestamp}, state) do
    if MessageTracker.can_process_message(state.message_tracker, message_id) do
      new_state = Impl.handle_introspection(state, payload, message_id, timestamp)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:handle_control, payload, path, message_id, timestamp}, state) do
    if MessageTracker.can_process_message(state.message_tracker, message_id) do
      new_state = Impl.handle_control(state, payload, path, message_id, timestamp)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_call(
        {:handle_install_volatile_trigger, object_id, object_type, parent_id, trigger_id,
         simple_trigger, trigger_target},
        _from,
        state
      ) do
    {return_value, new_state} =
      Impl.handle_install_volatile_trigger(
        state,
        object_id,
        object_type,
        parent_id,
        trigger_id,
        simple_trigger,
        trigger_target
      )

    {:reply, return_value, new_state}
  end

  def handle_call({:handle_delete_volatile_trigger, trigger_id}, _from, state) do
    {result, new_state} = Impl.handle_delete_volatile_trigger(state, trigger_id)

    {:reply, result, new_state}
  end

  def handle_call({:dump_state}, _from, state) do
    {:reply, state, state}
  end

  def handle_info({:initialize, realm, device_id, message_tracker}, nil) do
    {:noreply, Impl.init_state(realm, device_id, message_tracker)}
  end

  def handle_info({:DOWN, _, :process, _pid, :shutdown}, state) do
    {:stop, :shutdown, state}
  end

  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    {:stop, :monitored_process_died, state}
  end
end
