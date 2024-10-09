#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
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
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl
  alias Astarte.DataUpdaterPlant.MessageTracker

  def start(realm, device_id, message_tracker, opts \\ []) do
    GenServer.start(__MODULE__, {realm, device_id, message_tracker}, opts)
  end

  def init({realm, device_id, message_tracker}) do
    timeout = Config.data_updater_deactivation_interval_ms!()

    {:ok, Impl.init_state(realm, device_id, message_tracker), timeout}
  end

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

  def handle_cast({:handle_control, payload, path, message_id, timestamp}, state) do
    timeout = Config.data_updater_deactivation_interval_ms!()

    if MessageTracker.can_process_message(state.message_tracker, message_id) do
      new_state = Impl.handle_control(state, payload, path, message_id, timestamp)
      {:noreply, new_state}
    else
      {:noreply, state, timeout}
    end
  end

  def handle_call({:dump_state}, _from, state) do
    timeout = Config.data_updater_deactivation_interval_ms!()

    {:reply, state, state, timeout}
  end

  def handle_call({:start_device_deletion, timestamp}, _from, state) do
    {result, new_state} = Impl.start_device_deletion(state, timestamp)
    {:reply, result, new_state}
  end

  def handle_info({:DOWN, _, :process, pid, :normal}, %{message_tracker: pid} = state) do
    # This is a MessageTracker normally terminating due to deactivation
    {:noreply, state}
  end

  def handle_info({:DOWN, _, :process, _pid, :shutdown}, state) do
    {:stop, :shutdown, state}
  end

  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    {:stop, :monitored_process_died, state}
  end

  def handle_info(:timeout, state) do
    :ok = Impl.handle_deactivation(state)
    :ok = MessageTracker.deactivate(state.message_tracker)

    {:stop, :normal, state}
  end
end
