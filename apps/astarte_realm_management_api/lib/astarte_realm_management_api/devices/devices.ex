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

defmodule Astarte.RealmManagement.API.Devices do
  alias Astarte.RealmManagement.API.Devices.Queries
  alias Astarte.Core.Device

  def delete_device(realm_name, device_id) do
    with {:ok, decoded_id} <- Device.decode_device_id(device_id),
         :ok <- ensure_device_exists(realm_name, decoded_id) do
      Queries.insert_device_into_deletion_in_progress(realm_name, decoded_id)
      :ok
    end
  end

  def ensure_device_exists(realm_name, device_id) do
    case Queries.check_device_exists(realm_name, device_id) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :device_not_found}
    end
  end
end
