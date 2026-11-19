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

defmodule Astarte.TestSuite.Helpers.DeviceTest do
  use ExUnit.Case, async: true

  import Astarte.TestSuite.CaseContext

  alias Astarte.Core.Interface
  alias Astarte.TestSuite.Helpers.Device, as: DeviceHelper

  describe "devices/1" do
    test "creates generated devices in the canonical graph" do
      %{devices: devices} = DeviceHelper.devices(graph_context(true))

      assert map_size(devices) == 2

      for {encoded_id, {%{connected: connected, encoded_id: generated_id}, owner_id}} <- devices do
        assert connected
        assert encoded_id == generated_id
        assert owner_id == "interface"
      end
    end

    test "creates disconnected devices when requested" do
      %{devices: devices} = DeviceHelper.devices(graph_context(false))

      for {_encoded_id, {%{connected: connected}, _owner_id}} <- devices do
        refute connected
      end
    end
  end

  describe "data/1" do
    test "sets registration state for an empty graph" do
      context = DeviceHelper.data(%{interfaces: %{}, devices: %{}})

      assert context.devices_registered?
      assert context.device_database_results == []
    end
  end

  defp graph_context(device_connected) do
    %{}
    |> put!(:instances, "astarte1", "astarte1", nil)
    |> put!(:realms, "realm1", %{id: "realm1", instance_id: "astarte1"}, "astarte1")
    |> put!(
      :interfaces,
      "interface",
      %Interface{name: "interface", major_version: 1, minor_version: 0},
      "realm1"
    )
    |> Map.put(:device_number, 2)
    |> Map.put(:device_connected, device_connected)
  end
end
