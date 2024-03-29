#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Astarte.AppEngine.API.V2DeviceTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  use Astarte.Test.Cases.Device

  alias Ecto.Changeset
  alias StreamData
  alias Astarte.Core.Mapping
  alias Astarte.Core.Interface
  alias Astarte.AppEngine.API.Stats
  alias Astarte.AppEngine.API.Stats.DevicesStats
  alias Astarte.Test.Setups.Database, as: DatabaseSetup
  alias Astarte.Test.Setups.Interface, as: InterfaceSetup
  alias Astarte.Test.Generators.String, as: StringGenerator
  alias Astarte.Test.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Test.Generators.Mapping, as: MappingGenerator
  alias Astarte.Test.Generators.Device, as: DeviceGenerator
  alias Astarte.Test.Helpers.Database, as: DatabaseHelper

  @moduletag :v2
  @moduletag :device
  @moduletag interface_count: 10
  @moduletag device_count: 100

  describe "device generator testing" do
    property "validate device with pre-generated interfaces", %{interfaces: interfaces} do
      check all device <- DeviceGenerator.device(interfaces: interfaces) do
        :ok
      end
    end
  end

  describe "devices fixtures testing" do
    test "validate inserted devices", %{
      cluster: cluster,
      keyspace: keyspace,
      devices: devices
    } do
      list = DatabaseHelper.select!(:device, cluster, keyspace, devices)
      fields = [:device_id, :encoded_id]

      for field <- fields do
        f = fn l -> Enum.map(l, fn d -> d[field] end) end
        devices_ids_a = f.(devices)
        devices_ids_b = f.(list)
        assert [] === devices_ids_a -- devices_ids_b
        assert [] === devices_ids_b -- devices_ids_a
      end
    end
  end
end
