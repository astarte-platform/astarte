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

defmodule Astarte.Core.Generators.Triggers.SimpleConfigs.DeviceTriggerConfigTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Interface
  import Astarte.Core.Generators.Triggers.SimpleConfigs.DeviceTriggerConfig
  import Astarte.Core.Generators.Triggers.SimpleConfigs.Scope

  alias Astarte.Core.Interface
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger

  @interface_match_conditions [
    :INTERFACE_ADDED,
    :INTERFACE_REMOVED,
    :INTERFACE_MINOR_UPDATED
  ]

  @no_interface_conditions [
    :DEVICE_CONNECTED,
    :DEVICE_DISCONNECTED,
    :DEVICE_EMPTY_CACHE_RECEIVED,
    :DEVICE_ERROR,
    :INCOMING_INTROSPECTION,
    :DEVICE_REGISTERED,
    :DEVICE_DELETION_STARTED,
    :DEVICE_DELETION_FINISHED
  ]

  describe "triggers device_trigger_config generator" do
    property "generates valid device_trigger_config" do
      check all device_trigger_config <- device_trigger_config() do
        assert %DeviceTrigger{} = device_trigger_config

        assert device_trigger_config ==
                 device_trigger_config |> DeviceTrigger.encode() |> DeviceTrigger.decode()
      end
    end

    property "uses the generated interface in interface-matching conditions" do
      check all %Interface{name: interface_name, major_version: interface_major} = interface <-
                  interface(),
                device_event_type <- member_of(@interface_match_conditions),
                device_trigger_config <-
                  device_trigger_config(
                    device_event_type: device_event_type,
                    interface: interface
                  ) do
        assert %DeviceTrigger{
                 device_event_type: ^device_event_type,
                 interface_name: ^interface_name,
                 interface_major: ^interface_major
               } = device_trigger_config
      end
    end

    property "does not generate an interface for unrelated conditions" do
      check all device_event_type <- member_of(@no_interface_conditions),
                device_trigger_config <-
                  device_trigger_config(device_event_type: device_event_type) do
        assert %DeviceTrigger{
                 device_event_type: ^device_event_type,
                 interface_name: nil,
                 interface_major: 0
               } = device_trigger_config
      end
    end

    property "supports the any-interface match where Core allows it" do
      check all device_event_type <- member_of([:INTERFACE_ADDED, :INTERFACE_REMOVED]),
                device_trigger_config <-
                  device_trigger_config(
                    device_event_type: device_event_type,
                    interface: constant(:any_interface)
                  ) do
        assert %DeviceTrigger{
                 device_event_type: ^device_event_type,
                 interface_name: "*",
                 interface_major: 0
               } = device_trigger_config
      end
    end

    property "uses a bottom-up trigger scope" do
      check all scope <- trigger_scope(),
                device_trigger_config <- device_trigger_config(scope: scope) do
        %DeviceTrigger{device_id: device_id, group_name: group_name} = device_trigger_config

        assert device_id == Map.get(scope, :device_id)
        assert group_name == Map.get(scope, :group_name)
      end
    end
  end
end
