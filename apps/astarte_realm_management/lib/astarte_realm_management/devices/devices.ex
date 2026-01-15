#
# This file is part of Astarte.
#
# Copyright 2023 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.Devices do
  alias Astarte.Core.Device
  alias Astarte.RealmManagement.DeviceRemoval
  alias Astarte.RealmManagement.Devices.Queries
  alias Astarte.RealmManagement.RPC.DataUpdaterPlant.Client, as: DevicesRPC
  alias Astarte.RealmManagement.TriggersHandler

  def delete_device(realm_name, device_id) do
    with {:ok, decoded_id} <- Device.decode_device_id(device_id),
         :ok <- ensure_device_exists(realm_name, decoded_id) do
      do_delete_device(realm_name, decoded_id)
      :ok
    end
  end

  def ensure_device_exists(realm_name, device_id) do
    if Queries.device_exists?(realm_name, device_id) do
      :ok
    else
      {:error, :device_not_found}
    end
  end

  defp do_delete_device(realm_name, device_id) do
    Queries.insert_device_into_deletion_in_progress(realm_name, device_id)

    if Queries.device_exists?(realm_name, device_id) do
      TriggersHandler.device_deletion_started(realm_name, device_id)
      DevicesRPC.start_device_deletion_rpc(realm_name, device_id)
      :ok
    else
      # Don't leave dangling entries. This should only ever run if the request was made for
      # a device already being deleted,the device check was made before
      # DeviceRemoval.Core.delete_device! started and the insert_device_into_deletion_in_progress
      # call was made after DeviceRemoval.Core.delete_device! ended
      DeviceRemoval.Queries.remove_device_from_deletion_in_progress!(realm_name, device_id)
    end
  end
end
