#
# This file is part of Astarte.
#
# Copyright 2022-2025 SECO Mind Srl
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

defmodule Astarte.AppEngine.API.Rooms.Queries do
  alias Astarte.DataAccess.Devices.Device, as: DatabaseDevice
  alias Astarte.Core.Device
  alias Astarte.AppEngine.API.Repo
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Devices.Device, as: DatabaseDevice
  alias Astarte.DataAccess.Consistency

  require Logger

  def verify_device_exists(realm_name, encoded_device_id) do
    with {:ok, decoded_device_id} <- Device.decode_device_id(encoded_device_id) do
      keyspace = Realm.keyspace_name(realm_name)

      opts = [
        prefix: keyspace,
        consistency: Consistency.device_info(:read),
        error: :device_does_not_exist
      ]

      result = Repo.fetch(DatabaseDevice, decoded_device_id, opts)

      case result do
        {:ok, _device} ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Device #{encoded_device_id} in realm #{realm_name} does not exist.",
            tag: "device_does_not_exist"
          )

          {:error, reason}
      end
    end
  end
end
