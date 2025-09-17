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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.DeviceDisconnectedEventTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Triggers.SimpleEvents.DeviceDisconnectedEvent

  alias Astarte.Core.Generators.Triggers.SimpleEvents.DeviceDisconnectedEvent,
    as: DeviceDisconnectedEventGenerator

  @moduletag :trigger
  @moduletag :simple_event
  @moduletag :device_disconnected_event

  @doc false
  describe "triggers device_disconnected_event generator" do
    @describetag :success
    @describetag :ut
    property "generates valid device_disconnected_event" do
      check all device_disconnected_event <-
                  DeviceDisconnectedEventGenerator.device_disconnected_event() do
        assert %DeviceDisconnectedEvent{} = device_disconnected_event
      end
    end

    property "generates valid changes using to_changes (gen)" do
      gen_device_disconnected_event_changes =
        DeviceDisconnectedEventGenerator.device_disconnected_event()
        |> DeviceDisconnectedEventGenerator.to_changes()

      check all changes <- gen_device_disconnected_event_changes do
        assert is_map(changes)
      end
    end

    property "generates valid changes using to_changes (struct)" do
      check all device_disconnected_event <-
                  DeviceDisconnectedEventGenerator.device_disconnected_event(),
                changes <- DeviceDisconnectedEventGenerator.to_changes(device_disconnected_event) do
        assert is_map(changes)
      end
    end
  end
end
