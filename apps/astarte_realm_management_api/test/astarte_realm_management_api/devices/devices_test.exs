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

defmodule Astarte.RealmManagement.API.DevicesTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties

  alias Astarte.RealmManagement.API.Devices
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.Core.Device

  describe "deletion in progress tests" do
    @describetag :devices
    test "device is inserted in deletion in progress on deletion request", %{
      realm: realm,
      device_id: device_id
    } do
      keyspace = Realm.keyspace_name(realm)
      {:ok, decoded_id} = Device.decode_device_id(device_id)

      assert :ok = Devices.delete_device(realm, device_id)

      [deletion] = Repo.all(DeletionInProgress, prefix: keyspace)
      _ = Repo.delete!(deletion)

      assert decoded_id == deletion.device_id
      refute DeletionInProgress.all_ack?(deletion)
    end

    property "does not delete a non existing device", %{realm: realm} do
      check all(encoded_device_id <- DeviceGenerator.encoded_id()) do
        assert {:error, :device_not_found} = Devices.delete_device(realm, encoded_device_id)
      end
    end
  end
end
