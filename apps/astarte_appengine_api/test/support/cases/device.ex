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

defmodule Astarte.Cases.Device do
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  use ExUnit.CaseTemplate
  use ExUnitProperties

  import Astarte.Helpers.Device

  setup_all %{realm_name: realm_name} do
    interfaces = interfaces_for_update()
    device = DeviceGenerator.device(interfaces: interfaces) |> Enum.at(0)

    insert_device_cleanly(realm_name, device, interfaces)
    Enum.each(interfaces, &insert_interface_cleanly(realm_name, &1))

    %{interfaces: interfaces, device: device}
  end

  defp interfaces_for_update do
    # make sure we have at least 1 interface of each type
    individual_datastream_device =
      list_of(individual_datastream(:device), min_length: 1) |> Enum.at(0)

    individual_datastream_server =
      list_of(individual_datastream(:server), min_length: 1) |> Enum.at(0)

    object_datastream_device = list_of(object_datastream(:device), min_length: 1) |> Enum.at(0)
    object_datastream_server = list_of(object_datastream(:server), min_length: 1) |> Enum.at(0)
    other_interfaces = list_of(InterfaceGenerator.interface()) |> Enum.at(0)
    properties_device = list_of(properties(:device), min_length: 1) |> Enum.at(0)
    properties_server = list_of(properties(:server), min_length: 1) |> Enum.at(0)
    fallible_interfaces = list_of(fallible(:server), min_length: 1) |> Enum.at(0)

    [
      individual_datastream_device,
      individual_datastream_server,
      object_datastream_device,
      object_datastream_server,
      other_interfaces,
      properties_device,
      properties_server,
      fallible_interfaces
    ]
    |> Enum.concat()
  end

  defp fallible(ownership) do
    InterfaceGenerator.interface(
      ownership: ownership,
      value_type: member_of(fallible_value_types())
    )
  end

  defp object_datastream(ownership) do
    InterfaceGenerator.interface(ownership: ownership, aggregation: :object, type: :datastream)
  end

  defp individual_datastream(ownership) do
    InterfaceGenerator.interface(
      ownership: ownership,
      aggregation: :individual,
      type: :datastream
    )
  end

  defp properties(ownership) do
    InterfaceGenerator.interface(ownership: ownership, type: :properties)
  end
end
