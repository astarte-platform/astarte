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
    interface_specs = [
      {:individual_datastream_device,
       fn acc -> new_interfaces(individual_datastream_device(), acc) end},
      {:individual_datastream_server,
       fn acc -> new_interfaces(individual_datastream_server(), acc) end},
      {:object_datastream_device, fn acc -> new_interfaces(object_datastream_device(), acc) end},
      {:object_datastream_server, fn acc -> new_interfaces(object_datastream_server(), acc) end},
      {:properties_device, fn acc -> new_interfaces(properties_device(), acc) end},
      {:properties_server, fn acc -> new_interfaces(properties_server(), acc) end},
      {:fallible_interfaces, fn acc -> new_interfaces(fallible_interfaces(), acc) end},
      {:individual_downsampable, fn acc -> new_interfaces(individual_downsampable(), acc) end},
      {:object_downsampable, fn acc -> new_interfaces(object_downsampable(), acc) end},
      {:properties_server_allow_unset,
       fn acc -> new_interfaces(properties_server_allow_unset(), acc) end},
      {:properties_server_without_unset,
       fn acc -> new_interfaces(properties_server_without_unset(), acc) end},
      {:explicit_timestamps, fn acc -> new_interfaces(explicit_timestamps(), acc) end},
      {:other_interfaces, fn acc -> new_interfaces(other_interfaces(), acc) end}
    ]

    {all_interfaces, named_interfaces} =
      Enum.reduce(interface_specs, {[], %{}}, fn {name, gen_fn}, {acc_interfaces, named} ->
        new_ifaces = gen_fn.(acc_interfaces)
        updated_interfaces = Enum.concat(acc_interfaces, new_ifaces)
        updated_named = Map.put(named, name, new_ifaces)
        {updated_interfaces, updated_named}
      end)

    interfaces =
      %{
        individual_datastream_device: named_interfaces.individual_datastream_device,
        individual_datastream_server: named_interfaces.individual_datastream_server,
        object_datastream_device: named_interfaces.object_datastream_device,
        object_datastream_server: named_interfaces.object_datastream_server,
        properties_device: named_interfaces.properties_device,
        properties_server: named_interfaces.properties_server,
        fallible_interfaces: named_interfaces.fallible_interfaces,
        individual_downsampable: named_interfaces.individual_downsampable,
        object_downsampable: named_interfaces.object_downsampable,
        properties_server_allow_unset: named_interfaces.properties_server_allow_unset,
        properties_server_without_unset: named_interfaces.properties_server_without_unset,
        explicit_timestamps: named_interfaces.explicit_timestamps,
        other_interfaces: named_interfaces.other_interfaces
      }

    %{
      interfaces: all_interfaces,
      downsampable_individual_interfaces: interfaces.individual_downsampable,
      downsampable_object_interfaces: interfaces.object_downsampable,
      explicit_timestamp_interfaces: interfaces.explicit_timestamps
    }
  end

  defp new_interfaces(interface_gen, previous_interfaces) do
    installed_interfaces = previous_interfaces |> Enum.map(&{&1.name, &1.major_version})

    installed_normalized_interfaces =
      previous_interfaces |> Enum.map(&normalize_name(&1.name))

    interface_gen =
      interface_gen
      |> filter(fn interface ->
        name_and_major = {interface.name, interface.major_version}
        normalized_name = normalize_name(interface.name)

        name_and_major not in installed_interfaces and
          normalized_name not in installed_normalized_interfaces
      end)

    interface_gen
    |> list_of(min_length: 1)
    |> Enum.at(0)
    |> cleanup_duplicates()
  end

  defp cleanup_duplicates(interfaces) do
    interfaces
    |> Enum.reduce([], fn new_interface, acc_interfaces ->
      prev = acc_interfaces |> Enum.map(&{&1.name, &1.major_version})
      prev_normalized = acc_interfaces |> Enum.map(&normalize_name(&1.name))
      name_and_major = {new_interface.name, new_interface.major_version}
      normalized_name = normalize_name(new_interface.name)

      if name_and_major not in prev and normalized_name not in prev_normalized do
        [new_interface | acc_interfaces]
      else
        acc_interfaces
      end
    end)
    |> Enum.reverse()
  end

  defp normalize_name(interface_name) do
    interface_name
    |> String.replace("-", "")
    |> String.replace(".", "")
    |> String.downcase()
  end

  defp individual_datastream_device do
    [ownership: :device, aggregation: :individual, type: :datastream]
    |> InterfaceGenerator.interface()
  end

  defp individual_datastream_server do
    [ownership: :server, aggregation: :individual, type: :datastream]
    |> InterfaceGenerator.interface()
  end

  defp object_datastream_device do
    [ownership: :device, aggregation: :object, type: :datastream]
    |> InterfaceGenerator.interface()
  end

  defp object_datastream_server do
    [ownership: :server, aggregation: :object, type: :datastream]
    |> InterfaceGenerator.interface()
  end

  defp properties_device do
    [ownership: :device, type: :properties]
    |> InterfaceGenerator.interface()
  end

  defp properties_server do
    [ownership: :server, type: :properties]
    |> InterfaceGenerator.interface()
  end

  defp properties_server_allow_unset do
    [ownership: :server, type: :properties]
    |> InterfaceGenerator.interface()
    |> map(&customize_mappings(&1, allow_unset: true))
  end

  defp properties_server_without_unset do
    [ownership: :server, type: :properties]
    |> InterfaceGenerator.interface()
    |> map(&customize_mappings(&1, allow_unset: false))
  end

  defp fallible_interfaces do
    [ownership: :server]
    |> InterfaceGenerator.interface()
    |> map(&customize_mappings(&1, value_type: Enum.random(fallible_value_types())))
  end

  defp individual_downsampable do
    [aggregation: :individual]
    |> InterfaceGenerator.interface()
    |> map(&customize_mappings(&1, value_type: Enum.random(downsampable_value_types())))
  end

  defp object_downsampable do
    [type: :datastream, aggregation: :object]
    |> InterfaceGenerator.interface()
    |> map(&customize_mappings(&1, value_type: Enum.random(downsampable_value_types())))
  end

  defp explicit_timestamps do
    [ownership: :server, type: :datastream, explicit_timestamp: true]
    |> InterfaceGenerator.interface()
  end

  defp other_interfaces do
    InterfaceGenerator.interface()
  end
end
