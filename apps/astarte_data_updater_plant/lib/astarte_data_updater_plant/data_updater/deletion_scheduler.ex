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
defmodule Astarte.DataUpdater.DeletionScheduler do
  @moduledoc """
  This module sends messages to start deletion to a
  Astarte.DataUpdater.Server. When a deletion notice
  is received, the Server will start the device deletion
  procedure, write the dup_start_ack to db, and
  synchronously acknowledge it to the Scheduler.
  """
  use GenServer

  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.Core.Device
  alias Astarte.Core.CQLUtils
  alias Mississippi.Consumer.DataUpdater

  require Logger

  # TODO expose this via config
  @reconciliation_timeout :timer.minutes(5)
  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    # TODO: manually start_device_deletion!() when needed
    schedule_next_device_deletion()
    {:ok, %{}}
  end

  def handle_info(:delete_devices, state) do
    _ = Logger.debug("Reconciling devices for whom deletion shall begin")

    start_device_deletion!()
    schedule_next_device_deletion()
    {:noreply, state}
  end

  defp start_device_deletion! do
    retrieve_devices_to_delete!()
    |> Enum.each(fn %{realm_name: realm_name, device_id: device_id} ->
      timestamp = now_us_x10_timestamp()
      {:ok, pid} = DataUpdater.get_data_updater_process({realm_name, device_id})
      :ok = DataUpdater.handle_signal(pid, {:start_device_deletion, timestamp})
    end)
  end

  defp schedule_next_device_deletion do
    Process.send_after(self(), :delete_devices, @reconciliation_timeout)
  end

  defp retrieve_devices_to_delete! do
    realms = Queries.retrieve_realms!()

    for %{"realm_name" => realm_name} <- realms,
        keyspace_name =
          CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!()),
        %{"device_id" => device_id} <-
          Queries.retrieve_devices_waiting_to_start_deletion!(keyspace_name) do
      _ =
        Logger.debug("Retrieved device to delete",
          tag: "device_to_delete",
          realm_name: realm_name,
          encoded_device_id: Device.encode_device_id(device_id)
        )

      %{realm_name: realm_name, device_id: device_id}
    end
  end

  # TODO this is copied from astarte_vmq_plugin
  defp now_us_x10_timestamp do
    DateTime.utc_now()
    |> DateTime.to_unix(:microsecond)
    |> Kernel.*(10)
  end
end
