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

defmodule Astarte.TestSuite.Cases.DeviceTest do
  use ExUnit.Case, async: true

  import Astarte.TestSuite.CaseContext

  alias Astarte.Core.Interface

  alias Astarte.TestSuite.Cases.Device, as: DeviceCase

  test "normalizes device defaults" do
    assert DeviceCase.normalize_config!([], interface_context()).devices
           |> Map.fetch!("interface.device")
           |> elem(0)
           |> Map.fetch!(:name) ==
             "interface.device"
  end

  test "normalizes device configuration" do
    devices = %{"device-2" => {%{name: "device-2"}, "interface"}}

    assert DeviceCase.normalize_config!(
             [devices: devices, allow_missing_credentials: true],
             interface_context()
           ).devices
           |> Map.fetch!("device-2")
           |> elem(0)
           |> Map.fetch!(:name) == "device-2"
  end

  defp interface_context do
    %{}
    |> put!(:instances, "astarte1", "astarte1", nil)
    |> put!(:realms, "realm1", %{id: "realm1", instance_id: "astarte1"}, "astarte1")
    |> put!(:interfaces, "interface", %Interface{name: "interface"}, "realm1")
  end
end
