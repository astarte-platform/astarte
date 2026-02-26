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

defmodule Astarte.Core.Generators.Triggers.SimpleEvents.IncomingIntrospectionEventTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Interface
  alias Astarte.Core.Triggers.SimpleEvents.IncomingIntrospectionEvent
  alias Astarte.Core.Triggers.SimpleEvents.InterfaceVersion

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  alias Astarte.Core.Generators.Triggers.SimpleEvents.IncomingIntrospectionEvent,
    as: IncomingIntrospectionEventGenerator

  @moduletag :trigger
  @moduletag :simple_event
  @moduletag :incoming_introspection_event

  defp introspection_keys(introspection_map), do: MapSet.new(Map.keys(introspection_map))

  defp interface_names(interfaces),
    do: MapSet.new(Enum.map(interfaces, fn %Interface{name: name} -> name end))

  defp gen_interface_introspection do
    gen all interfaces <- InterfaceGenerator.interface() |> list_of(max_length: 10),
            %IncomingIntrospectionEvent{introspection_map: introspection_map} <-
              IncomingIntrospectionEventGenerator.incoming_introspection_event(
                interfaces: interfaces
              ),
            introspection_keys = introspection_keys(introspection_map),
            interface_names = interface_names(interfaces) do
      {
        interfaces,
        interface_names,
        introspection_map,
        introspection_keys
      }
    end
  end

  describe "triggers incoming_introspection_event generator" do
    @describetag :success
    @describetag :ut
    property "generates valid incoming_introspection_event" do
      check all incoming_introspection_event <-
                  IncomingIntrospectionEventGenerator.incoming_introspection_event() do
        assert %IncomingIntrospectionEvent{} = incoming_introspection_event
      end
    end

    property "introspection_map keys match interfaces" do
      check all {_interfaces, interface_names, _introspection_map, introspection_keys} <-
                  gen_interface_introspection() do
        assert introspection_keys == interface_names
      end
    end

    property "introspection_map versions match interfaces" do
      check all {interfaces, _interface_names, introspection_map, _introspection_keys} <-
                  gen_interface_introspection() do
        for %Interface{name: name, major_version: major_version, minor_version: minor_version} <-
              interfaces do
          {_key, %InterfaceVersion{major: major, minor: minor}} =
            Enum.find(introspection_map, fn {key, _value} -> key == name end)

          assert major == major_version and minor == minor_version
        end
      end
    end
  end
end
