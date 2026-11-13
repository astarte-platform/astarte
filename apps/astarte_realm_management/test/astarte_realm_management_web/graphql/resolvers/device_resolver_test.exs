#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.RealmManagementWeb.GraphQL.Resolvers.DeviceResolverTest do
  use Astarte.RealmManagement.Cases.Data, async: true
  use Astarte.RealmManagement.Cases.Device

  import Mimic

  alias Astarte.RealmManagement.RPC.DataUpdaterPlant.Client, as: DevicesRPC
  alias Astarte.RealmManagementWeb.GraphQL.Resolvers.DeviceResolver

  setup %{realm_name: realm_name, device_id: device_id} do
    resolution = %{
      context: %{
        realm_name: realm_name
      }
    }

    %{resolution: resolution, device_id: device_id}
  end

  describe "delete_device/3" do
    test "schedules a device deletion when valid", %{
      resolution: resolution,
      device_id: device_id,
      realm_name: realm_name,
      decoded_device_id: decoded_device_id
    } do
      device = %{
        device_id: decoded_device_id,
        interfaces_bytes: %{},
        interfaces_msgs: %{}
      }

      Astarte.RealmManagement.Helpers.Device.insert_device_cleanly(realm_name, device, [], [])

      DevicesRPC
      |> expect(:start_device_deletion_rpc, fn _, _ -> :ok end)

      args = %{device_id: device_id}

      assert {:ok, "Device deletion initiated"} =
               DeviceResolver.delete_device(nil, args, resolution)
    end

    test "returns an error when the device does not exist", %{resolution: resolution} do
      # Note: The database layer usually raises or returns specific errors.
      # Let's use a randomly generated valid id that isn't in DB.
      args = %{device_id: "e-k5eS00T--e0m-9_kF9Mw"}

      assert {:error, ":device_not_found"} = DeviceResolver.delete_device(nil, args, resolution)
    end
  end

  describe "missing context" do
    test "returns error when realm_name is missing" do
      resolution = %{context: %{}}

      assert {:error, "Missing realm context"} =
               DeviceResolver.delete_device(nil, %{}, resolution)
    end
  end
end
