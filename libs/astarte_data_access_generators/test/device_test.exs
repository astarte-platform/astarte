#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.DataAccess.Generators.DeviceTest do
  @moduledoc """
  Tests for Astarte Device generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.CQLUtils

  alias Astarte.Core.Generators.Device, as: DeviceGenerator

  alias Astarte.DataAccess.Devices.Device, as: DeviceData

  alias Astarte.DataAccess.Generators.Device, as: DeviceDataGenerator

  @moduletag :device

  @doc false
  describe "device from_core/1" do
    @describetag :success
    @describetag :ut

    property "using from_core (gen)" do
      check all device <- DeviceGenerator.device() |> DeviceDataGenerator.from_core() do
        assert is_struct(device, DeviceData)
      end
    end

    property "using from_core (struct)" do
      check all device <- DeviceGenerator.device(),
                device_data <- DeviceDataGenerator.from_core(device) do
        assert is_struct(device_data, DeviceData)
      end
    end
  end
end
