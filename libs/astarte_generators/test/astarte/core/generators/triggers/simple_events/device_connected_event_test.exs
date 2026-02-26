#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.DeviceConnectedEventTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Triggers.SimpleEvents.DeviceConnectedEvent

  alias Astarte.Core.Generators.Triggers.SimpleEvents.DeviceConnectedEvent,
    as: DeviceConnectedEventGenerator

  @moduletag :trigger
  @moduletag :simple_event
  @moduletag :device_connected_event

  @doc false
  describe "triggers device_connected_event generator" do
    @describetag :success
    @describetag :ut
    property "generates valid device_connected_event" do
      check all device_connected_event <- DeviceConnectedEventGenerator.device_connected_event() do
        assert %DeviceConnectedEvent{} = device_connected_event
      end
    end

    property "device_connected_event generates valid ip address ipv4" do
      check all %DeviceConnectedEvent{
                  device_ip_address: device_ip_address
                } <- DeviceConnectedEventGenerator.device_connected_event(),
                ipv4_address = String.to_charlist(device_ip_address) do
        assert {:ok, _} = :inet.parse_ipv4_address(ipv4_address)
      end
    end
  end
end
