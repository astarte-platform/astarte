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
  use Astarte.RealmManagement.API.DataCase, async: true
  use ExUnitProperties

  alias Astarte.RealmManagement.API.Devices
  alias Astarte.RealmManagement.API.Helpers.RPCMock.DB
  alias Astarte.Core.Generators.Device, as: DeviceGenerator

  describe "property based device tests" do
    @describetag :devices
    property "delete device succeeds when the device exists", %{realm: realm} do
      check all(device_id <- DeviceGenerator.encoded_id()) do
        DB.create_device(realm, device_id)
        assert :ok = Devices.delete_device(realm, device_id)
      end
    end

    property "delete device fails on a non-existing device", %{realm: realm} do
      check all(device_id <- DeviceGenerator.encoded_id()) do
        assert {:error, :device_not_found} = Devices.delete_device(realm, device_id)
      end
    end
  end
end
