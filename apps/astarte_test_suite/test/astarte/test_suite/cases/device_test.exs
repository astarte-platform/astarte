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

defmodule Astarte.TestSuite.Cases.DeviceTest do
  use ExUnit.Case, async: true

  import Astarte.TestSuite.CaseContext

  alias Astarte.Core.Interface

  alias Astarte.TestSuite.Cases.Device, as: DeviceCase

  describe "normalize_config!/2" do
    test "normalizes device defaults" do
      context = DeviceCase.normalize_config!([], interface_context())

      assert context.device_number == 1
      assert map_size(context.devices) == 1

      for {encoded_id, {%{encoded_id: generated_id}, owner_id}} <- context.devices do
        assert encoded_id == generated_id
        assert owner_id == "interface"
      end
    end

    test "normalizes device configuration" do
      devices = %{"device-2" => {%{name: "device-2"}, "interface"}}

      context =
        DeviceCase.normalize_config!(
          [device_number: 2, devices: devices, allow_missing_credentials: true],
          interface_context()
        )

      assert context.device_number == 2
      assert context.devices == devices
      assert context.allow_missing_credentials
    end
  end

  defp interface_context do
    %{}
    |> put!(:instances, "astarte1", "astarte1", nil)
    |> put!(:realms, "realm1", %{id: "realm1", instance_id: "astarte1"}, "astarte1")
    |> put!(
      :interfaces,
      "interface",
      %Interface{name: "interface", major_version: 1, minor_version: 0},
      "realm1"
    )
  end
end
