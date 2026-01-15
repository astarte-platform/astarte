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
  alias Astarte.DataAccess.Interface

  use ExUnit.CaseTemplate
  use ExUnitProperties

  import Astarte.Helpers.Device
  import Astarte.InterfaceUpdateGenerators

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  setup_all %{realm_name: realm_name} do
    interfaces_data = interfaces_for_update()
    device = DeviceGenerator.device(interfaces: interfaces_data.interfaces) |> Enum.at(0)

    insert_device_cleanly(realm_name, device, interfaces_data.interfaces)
    Enum.each(interfaces_data.interfaces, &insert_interface_cleanly(realm_name, &1))

    Map.put(interfaces_data, :device, device)
  end

  def populate_interfaces(context) do
    %{
      realm_name: realm_name,
      interfaces: interfaces,
      device: device,
      downsampable_individual_interfaces: individual_downsampable,
      downsampable_object_interfaces: object_downsampable
    } = context

    downsampable_individual_interface = Enum.random(individual_downsampable)
    downsampable_object_interface = Enum.random(object_downsampable)

    taken_interfaces = [
      downsampable_individual_interface,
      downsampable_object_interface
    ]

    random_interfaces =
      interfaces
      |> Enum.reject(&(&1 in taken_interfaces))
      |> Enum.group_by(fn interface ->
        {interface.type, interface.ownership, interface.aggregation}
      end)
      |> Map.new(fn {key, values} -> {key, Enum.random(values)} end)

    individual_datastream_device =
      Map.fetch!(random_interfaces, {:datastream, :device, :individual})

    individual_datastream_server =
      Map.fetch!(random_interfaces, {:datastream, :server, :individual})

    object_datastream_device = Map.fetch!(random_interfaces, {:datastream, :device, :object})
    object_datastream_server = Map.fetch!(random_interfaces, {:datastream, :server, :object})

    individual_properties_device =
      Map.fetch!(random_interfaces, {:properties, :device, :individual})

    individual_properties_server =
      Map.fetch!(random_interfaces, {:properties, :server, :individual})

    flags = %{
      downsampable_object_interface => [:complete_update]
    }

    interfaces_with_data =
      [
        individual_datastream_device,
        individual_datastream_server,
        object_datastream_device,
        object_datastream_server,
        individual_properties_device,
        individual_properties_server,
        downsampable_individual_interface,
        downsampable_object_interface
      ]

    interface_data =
      for interface <- interfaces_with_data, into: %{} do
        flags = Map.get(flags, interface, [])
        interface_data = populate(realm_name, device.device_id, interface, flags)
        interface_key = {interface.name, interface.major_version}

        {interface_key, interface_data}
      end

    registered_paths = Map.new(interface_data, fn {key, data} -> {key, data.paths} end)
    registered_timings = Map.new(interface_data, fn {key, data} -> {key, data.timings} end)

    %{
      registered_paths: registered_paths,
      registered_timings: registered_timings,
      interfaces_with_data: interfaces_with_data,
      individual_datastream_device_interface: individual_datastream_device,
      individual_datastream_server_interface: individual_datastream_server,
      object_datastream_device_interface: object_datastream_device,
      object_datastream_server_interface: object_datastream_server,
      individual_properties_device_interface: individual_properties_device,
      individual_properties_server_interface: individual_properties_server,
      downsampable_individual_interface: downsampable_individual_interface,
      downsampable_object_interface: downsampable_object_interface
    }
  end

  defp populate(realm_name, device_id, interface, flags) do
    {:ok, descriptor} =
      Interface.fetch_interface_descriptor(realm_name, interface.name, interface.major_version)

    mapping_update =
      case :complete_update in flags do
        true -> valid_complete_mapping_update_for(interface)
        false -> valid_mapping_update_for(interface)
      end

    values =
      list_of(mapping_update, length: 100..10_000)
      |> Enum.at(0)

    timings = insert_values(realm_name, device_id, descriptor, values)
    paths = MapSet.new(values, & &1.path)

    %{paths: paths, timings: timings}
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

    properties_server_allow_unset =
      list_of(properties(:server, true), min_length: 1) |> Enum.at(0)

    fallible_interfaces = list_of(fallible(:server), min_length: 1) |> Enum.at(0)
    individual_downsampable = list_of(individual_downsampable(), min_length: 1) |> Enum.at(0)
    object_downsampable = list_of(object_downsampable(), min_length: 1) |> Enum.at(0)

    explicit_timestamps =
      [ownership: :server, type: :datastream, explicit_timestamp: true]
      |> InterfaceGenerator.interface()
      |> list_of(min_length: 1)
      |> Enum.at(0)

    all_interfaces =
      [
        individual_datastream_device,
        individual_datastream_server,
        object_datastream_device,
        object_datastream_server,
        other_interfaces,
        properties_device,
        properties_server,
        fallible_interfaces,
        individual_downsampable,
        object_downsampable,
        properties_server_allow_unset,
        explicit_timestamps
      ]
      |> Enum.concat()

    %{
      interfaces: all_interfaces,
      downsampable_individual_interfaces: individual_downsampable,
      downsampable_object_interfaces: object_downsampable,
      explicit_timestamp_interfaces: explicit_timestamps
    }
  end

  defp fallible(ownership) do
    InterfaceGenerator.interface(
      ownership: ownership,
      value_type: member_of(fallible_value_types())
    )
  end

  defp individual_downsampable do
    InterfaceGenerator.interface(
      aggregation: :individual,
      value_type: member_of(downsampable_value_types())
    )
  end

  defp object_downsampable do
    InterfaceGenerator.interface(
      type: :datastream,
      aggregation: :object,
      value_type: member_of(downsampable_value_types())
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

  defp properties(ownership, allow_unset \\ nil) do
    InterfaceGenerator.interface(
      ownership: ownership,
      type: :properties,
      allow_unset: allow_unset
    )
  end
end
