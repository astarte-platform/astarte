#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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
  @moduledoc false
  use ExUnit.CaseTemplate
  use ExUnitProperties

  import Astarte.Helpers.Device
  import Astarte.Helpers.Interface

  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  alias Astarte.DataAccess.Interface

  alias Astarte.Generators.InterfaceUpdate, as: InterfaceUpdateGenerator

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  setup_all %{realm_name: realm_name} do
    interfaces_data = interfaces_for_update()

    device =
      DeviceGenerator.device(interfaces: interfaces_data.interfaces) |> resize(10) |> Enum.at(0)

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
      Interface.fetch_interface_descriptor(
        realm_name,
        interface.name,
        interface.major_version
      )

    mapping_update =
      case :complete_update in flags do
        true -> InterfaceUpdateGenerator.valid_complete_mapping_update_for(interface)
        false -> InterfaceUpdateGenerator.valid_mapping_update_for(interface)
      end

    values =
      list_of(mapping_update, length: 100..10_000)
      |> Enum.at(0)

    timings = insert_values(realm_name, device_id, descriptor, values)
    paths = MapSet.new(values, & &1.path)

    %{paths: paths, timings: timings}
  end

  defp interfaces_for_update do
    interfaces =
      %{
        individual_datastream_device: individual_datastream_device(),
        individual_datastream_server: individual_datastream_server(),
        object_datastream_device: object_datastream_device(),
        object_datastream_server: object_datastream_server(),
        properties_device: properties_device(),
        properties_server: properties_server(),
        fallible_interfaces: fallible_interfaces(),
        individual_downsampable: individual_downsampable(),
        object_downsampable: object_downsampable(),
        properties_server_allow_unset: properties_server_allow_unset(),
        properties_server_without_unset: properties_server_without_unset(),
        explicit_timestamps: explicit_timestamps(),
        other_interfaces: other_interfaces()
      }

    %{
      interfaces: interfaces |> Map.values() |> Enum.concat(),
      downsampable_individual_interfaces: interfaces.individual_downsampable,
      downsampable_object_interfaces: interfaces.object_downsampable,
      explicit_timestamp_interfaces: interfaces.explicit_timestamps
    }
  end

  defp individual_datastream_device do
    [ownership: :device, aggregation: :individual, type: :datastream]
    |> InterfaceGenerator.interface()
    |> list_of(min_length: 1)
    |> Enum.at(0)
  end

  defp individual_datastream_server do
    [ownership: :server, aggregation: :individual, type: :datastream]
    |> InterfaceGenerator.interface()
    |> list_of(min_length: 1)
    |> Enum.at(0)
  end

  defp object_datastream_device do
    [ownership: :device, aggregation: :object, type: :datastream]
    |> InterfaceGenerator.interface()
    |> list_of(min_length: 1)
    |> Enum.at(0)
  end

  defp object_datastream_server do
    [ownership: :server, aggregation: :object, type: :datastream]
    |> InterfaceGenerator.interface()
    |> list_of(min_length: 1)
    |> Enum.at(0)
  end

  defp properties_device do
    [ownership: :device, type: :properties]
    |> InterfaceGenerator.interface()
    |> list_of(min_length: 1)
    |> Enum.at(0)
  end

  defp properties_server do
    [ownership: :server, type: :properties]
    |> InterfaceGenerator.interface()
    |> list_of(min_length: 1)
    |> Enum.at(0)
  end

  defp properties_server_allow_unset do
    [ownership: :server, type: :properties]
    |> InterfaceGenerator.interface()
    |> list_of(min_length: 1)
    |> Enum.at(0)
    |> customize_mappings(allow_unset: true)
  end

  defp properties_server_without_unset do
    [ownership: :server, type: :properties]
    |> InterfaceGenerator.interface()
    |> list_of(min_length: 1)
    |> Enum.at(0)
    |> customize_mappings(allow_unset: false)
  end

  defp fallible_interfaces do
    [ownership: :server]
    |> InterfaceGenerator.interface()
    |> list_of(min_length: 1)
    |> Enum.at(0)
    |> customize_mappings(value_type: Enum.random(fallible_value_types()))
  end

  defp individual_downsampable do
    [aggregation: :individual]
    |> InterfaceGenerator.interface()
    |> list_of(min_length: 1)
    |> Enum.at(0)
    |> customize_mappings(value_type: Enum.random(downsampable_value_types()))
  end

  defp object_downsampable do
    [type: :datastream, aggregation: :object]
    |> InterfaceGenerator.interface()
    |> list_of(min_length: 1)
    |> Enum.at(0)
    |> customize_mappings(value_type: Enum.random(downsampable_value_types()))
  end

  defp explicit_timestamps do
    [ownership: :server, type: :datastream, explicit_timestamp: true]
    |> InterfaceGenerator.interface()
    |> list_of(min_length: 1)
    |> Enum.at(0)
  end

  defp other_interfaces do
    InterfaceGenerator.interface()
    |> list_of()
    |> Enum.at(0)
  end
end
