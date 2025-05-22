#
# This file is part of Astarte.
#
# Copyright 2023 SECO Mind Srl
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
defmodule Astarte.RealmManagement.DeviceRemoval.Scheduler do
  @moduledoc """
  This module is used to start Astarte.RealmManagement.DeviceRemoval.DeviceRemover tasks.
  Starting a DeviceRemover may happen either at startup,
  when interrupted device deletions are resumed, or when
  the delete_device/2 function is called.
  A DeviceRemover might fail, therefore a Task.Supervisor
  handles restarting it.
  """

  use GenServer

  alias Astarte.RealmManagement.Queries
  alias Astarte.RealmManagement.DeviceRemoval.DeviceRemover

  require Logger

  # TODO expose this via config
  @reconciliation_timeout :timer.minutes(5)
  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_init_arg) do
    # TODO: find a way to run start_device_deletion!() manually
    schedule_device_deletion()
    {:ok, %{}}
  end

  def handle_info(:delete_devices, state) do
    _ = Logger.debug("Reconciling devices to delete")

    start_device_deletion!()
    schedule_device_deletion()
    {:noreply, state}
  end

  defp start_device_deletion!() do
    device_to_delete_list = retrieve_devices_to_delete!()

    Enum.each(device_to_delete_list, &start_device_deletion/1)
  end

  defp schedule_device_deletion() do
    Process.send_after(self(), :delete_devices, @reconciliation_timeout)
  end

  defp start_device_deletion(args) do
    Task.Supervisor.start_child(
      Astarte.RealmManagement.DeviceRemoverSupervisor,
      DeviceRemover,
      :run,
      [args],
      restart: :transient
    )
  end

  defp retrieve_devices_to_delete!() do
    realms = Queries.retrieve_realms!()

    Enum.flat_map(realms, fn %{realm_name: realm_name} ->
      devices = Queries.retrieve_devices_to_delete!(realm_name)
      Enum.map(devices, &Map.put(&1, :realm_name, realm_name))
    end)
  end
end
