#
# This file is part of Astarte.
#
# Copyright 2023-2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.DeviceRemoval.DeviceRemover do
  @moduledoc """
  This module handles data deletion for a device using a Task.
  The Task may fail at any time, notably if the database is not
  available.
  See Astarte.RealmManagement.DeviceRemoval.Scheduler for handling failures.
  """

  use Task
  require Logger
  alias Astarte.Core.Device
  alias Astarte.RealmManagement.DeviceRemoval.Core
  alias Astarte.RealmManagement.Devices
  alias Astarte.RealmManagement.DeviceRemoval

  @spec run(%{:device_id => <<_::128>>, :realm_name => binary()}) :: :ok | no_return()
  def run(%{realm_name: realm_name, device_id: device_id} = args) do
    if Devices.Queries.device_exists?(realm_name, device_id) do
      do_run(args)
    else
      cleanup(args)
    end
  end

  @spec do_run(%{:device_id => <<_::128>>, :realm_name => binary()}) :: :ok | no_return()
  defp do_run(%{realm_name: realm_name, device_id: device_id}) do
    encoded_device_id = Device.encode_device_id(device_id)
    _ = Logger.info("Starting to remove device #{encoded_device_id}", tag: "device_delete_start")

    Core.delete_individual_datastreams!(realm_name, device_id)
    Core.delete_individual_properties!(realm_name, device_id)
    Core.delete_object_datastream!(realm_name, device_id)
    Core.delete_aliases!(realm_name, device_id)
    Core.delete_groups!(realm_name, device_id)
    Core.delete_kv_store_entries!(realm_name, encoded_device_id)
    Core.delete_device!(realm_name, device_id)

    _ = Logger.info("Successfully removed device #{encoded_device_id}", tag: "device_delete_ok")
    :ok
  end

  @spec cleanup(%{:device_id => <<_::128>>, :realm_name => binary()}) :: :ok
  defp cleanup(%{realm_name: realm_name, device_id: device_id}) do
    # As the device is guaranteed to be deleted at least once, it may happen that a crash happened
    # between the device cancellation and the deletion in progress entry cancellation.
    # If we're here, we just need to delete the deletion in progress entry
    DeviceRemoval.Queries.remove_device_from_deletion_in_progress!(realm_name, device_id)
  end
end
