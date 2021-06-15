#
# This file is part of Astarte.
#
# Copyright 2021 Ispirata Srl
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

defmodule AstarteDeviceFleetSimulator.Scheduler do
  use GenServer, restart: :transient

  require Logger

  alias AstarteDeviceFleetSimulator.DynamicSupervisor
  alias AstarteDeviceFleetSimulator.Device
  alias AstarteDeviceFleetSimulator.Config

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    {:ok, Enum.into(Config.scheduler_opts(), %{}), {:continue, :init_messages}}
  end

  @impl true
  def handle_continue(:init_messages, state) do
    Process.send_after(self(), :spawn, state.spawn_interval_s)
    Process.send_after(self(), :terminate, state.test_duration_s)
    {:noreply, state}
  end

  def handle_info(:spawn, %{device_count: 0} = state) do
    Logger.info("Device spawn ended.")
    {:noreply, state}
  end

  @impl true
  def handle_info(:spawn, state) do
    Process.send_after(self(), :spawn, state.spawn_interval_s)
    spawn_device(state.device_count)
    {:noreply, %{state | device_count: state.device_count - 1}}
  end

  def handle_info(:terminate, state) do
    Logger.info("Simulation has ended successfully.")

    System.stop(0)
    {:stop, {:shutdown, :simulation_ended}, state}
  end

  defp spawn_device(device_count) do
    child = {Device, [device_count: device_count]}
    DynamicSupervisor.start_device(child)
  end
end
