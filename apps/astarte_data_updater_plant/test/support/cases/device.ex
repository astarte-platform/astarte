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
  @moduledoc """
  This module provides helper functions and setup for tests related to devices in the DataUpdaterPlant.
  """
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Mapping, as: MappingGenerator
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  use ExUnit.CaseTemplate
  use ExUnitProperties

  import Astarte.Helpers.Device
  import Astarte.Helpers.Database
  import Astarte.InterfaceUpdateGenerators

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  setup_all %{realm_name: realm_name} do
    interfaces_data = interfaces()
    device = DeviceGenerator.device(interfaces: interfaces_data.interfaces) |> Enum.at(0)

    Enum.each(interfaces_data.interfaces, &insert_interface_cleanly(realm_name, &1))

    interface_descriptors = get_interface_descriptors(realm_name, interfaces_data.interfaces)
    endpoints = get_endpoints_by_interface_id(realm_name, interface_descriptors)

    interfaces =
      interfaces_data.interfaces
      |> update_interfaces_id(interface_descriptors)
      |> update_endpoints_ids(endpoints)

    insert_device_cleanly(realm_name, device, interfaces)

    interfaces_data
    |> Map.put(:interfaces, interfaces)
    |> Map.put(:device, device)
    |> Map.put(:interface_descriptors, interface_descriptors)
    |> Map.put(:endpoints, endpoints)
  end

  def populate_interfaces(context) do
    %{
      realm_name: realm_name,
      interfaces: interfaces,
      interface_descriptors: interface_descriptors,
      server_property_with_all_endpoint_types: server_property_with_all_endpoint_types,
      device: device
    } = context

    descriptors_map =
      interface_descriptors
      |> Map.new(fn desc ->
        {desc.interface_id, desc}
      end)

    random_interfaces =
      interfaces
      |> List.delete(server_property_with_all_endpoint_types)
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

    interfaces_with_data =
      [
        individual_datastream_device,
        individual_datastream_server,
        object_datastream_device,
        object_datastream_server,
        individual_properties_device,
        individual_properties_server
      ]

    server_property_with_all_endpoint_types_data =
      populate_all_mappings(
        realm_name,
        device,
        server_property_with_all_endpoint_types,
        Map.fetch!(descriptors_map, server_property_with_all_endpoint_types.interface_id)
      )

    server_property_with_all_endpoint_types_key =
      {server_property_with_all_endpoint_types.name,
       server_property_with_all_endpoint_types.major_version}

    interface_data =
      for interface <- interfaces_with_data, into: %{} do
        interface_key = {interface.name, interface.major_version}
        descriptor = Map.fetch!(descriptors_map, interface.interface_id)
        interface_data = populate(realm_name, device, interface, descriptor)

        {interface_key, interface_data}
      end

    interface_data =
      interface_data
      |> Map.put(
        server_property_with_all_endpoint_types_key,
        server_property_with_all_endpoint_types_data
      )

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
      individual_properties_server_interface: individual_properties_server
    }
  end

  defp populate(realm_name, device, interface, interface_descriptor) do
    mapping_update = valid_mapping_update_for(interface)

    values =
      list_of(mapping_update, length: 100..10_000)
      |> Enum.at(0)

    timings = insert_values(realm_name, device, interface, interface_descriptor, values)
    paths = MapSet.new(values, & &1.path)

    %{paths: paths, timings: timings}
  end

  defp populate_all_mappings(realm_name, device, interface, interface_descriptor) do
    mapping_updates =
      interface.mappings
      |> Enum.map(&valid_mapping_update_for(interface, mapping: &1))
      |> Enum.map(&Enum.at(&1, 0))

    timings = insert_values(realm_name, device, interface, interface_descriptor, mapping_updates)
    paths = MapSet.new(mapping_updates, & &1.path)

    %{paths: paths, timings: timings}
  end

  defp update_interfaces_id(interfaces, interface_descriptors) do
    descriptors_by_key =
      Map.new(interface_descriptors, fn descriptor ->
        {{descriptor.name, descriptor.major_version}, descriptor}
      end)

    Enum.map(interfaces, fn interface ->
      interface_key = {interface.name, interface.major_version}
      interface_descriptor = Map.fetch!(descriptors_by_key, interface_key)

      interface
      |> Map.put(:interface_id, interface_descriptor.interface_id)
    end)
  end

  defp update_endpoints_ids(interfaces, endpoints) do
    for interface <- interfaces do
      interface_endpoints_by_path =
        Map.fetch!(endpoints, interface.interface_id)
        |> Map.new(&{&1.endpoint, &1})

      mappings =
        interface.mappings
        |> Enum.map(fn mapping ->
          endpoint = interface_endpoints_by_path[mapping.endpoint] || flunk("Endpoint not found")
          %{mapping | interface_id: interface.interface_id, endpoint_id: endpoint.endpoint_id}
        end)

      %{interface | mappings: mappings}
    end
  end

  defp interfaces do
    interface_specs = [
      {:individual_datastream_device,
       fn acc -> new_interfaces(individual_datastream(:device), acc, :list) end},
      {:individual_datastream_server,
       fn acc -> new_interfaces(individual_datastream(:server), acc, :list) end},
      {:object_datastream_server,
       fn acc -> new_interfaces(object_datastream(:server), acc, :list) end},
      {:object_datastream_device,
       fn acc -> new_interfaces(object_datastream(:device), acc, :list) end},
      {:properties_device, fn acc -> new_interfaces(properties(:device), acc, :list) end},
      {:properties_server, fn acc -> new_interfaces(properties(:server), acc, :list) end},
      {:server_property_with_all_endpoint_types,
       fn acc -> [new_interfaces(all_endpoint_types(:server, :properties), acc, :single)] end},
      {:fixed_endpoint_interface,
       fn acc -> [new_interfaces(fixed_endpoint_interface(), acc, :single)] end},
      {:other_interfaces,
       fn acc -> new_interfaces(InterfaceGenerator.interface(), acc, :list) end}
    ]

    {all_interfaces, named_interfaces} =
      Enum.reduce(interface_specs, {[], %{}}, fn {name, gen_fn}, {acc_interfaces, named} ->
        new_ifaces = gen_fn.(acc_interfaces)
        updated_interfaces = Enum.concat(acc_interfaces, new_ifaces)
        updated_named = Map.put(named, name, List.first(new_ifaces) || hd(new_ifaces))
        {updated_interfaces, updated_named}
      end)

    %{
      interfaces: all_interfaces,
      fixed_endpoint_interface: named_interfaces.fixed_endpoint_interface,
      server_property_with_all_endpoint_types:
        named_interfaces.server_property_with_all_endpoint_types
    }
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

  defp fixed_endpoint_interface do
    InterfaceGenerator.interface(ownership: :device, type: :datastream, aggregation: :individual)
    |> map(fn interface ->
      mapping = Enum.at(interface.mappings, 0)
      mapping = %{mapping | endpoint: "/value", value_type: :integer}

      %{interface | mappings: [mapping]}
    end)
  end

  defp all_endpoint_types(ownership, type) do
    gen all name <- InterfaceGenerator.name(),
            major <- InterfaceGenerator.major_version(),
            aggregation <- InterfaceGenerator.aggregation(type),
            mappings <- all_endpoint_mappings(type, name, major, aggregation),
            interface <-
              InterfaceGenerator.interface(
                name: name,
                major_version: major,
                ownership: ownership,
                type: type,
                aggregation: aggregation,
                mappings: mappings
              ) do
      interface
    end
  end

  defp all_endpoint_mappings(type, name, major, :individual) do
    gen all retention <- MappingGenerator.retention(type),
            reliability <- MappingGenerator.reliability(type),
            expiry <- MappingGenerator.expiry(type),
            allow_unset <- MappingGenerator.allow_unset(type),
            explicit_timestamp <- MappingGenerator.explicit_timestamp(type),
            params = [
              interface_major: major,
              interface_type: type,
              interface_name: name,
              retention: retention,
              reliability: reliability,
              expiry: expiry,
              allow_unset: allow_unset,
              explicit_timestamp: explicit_timestamp
            ],
            double_mappings <- mappings(:double, params),
            integer_mappings <- mappings(:integer, params),
            boolean_mappings <- mappings(:boolean, params),
            longinteger_mappings <- mappings(:longinteger, params),
            string_mappings <- mappings(:string, params),
            binaryblob_mappings <- mappings(:binaryblob, params),
            datetime_mappings <- mappings(:datetime, params),
            doublearray_mappings <- mappings(:doublearray, params),
            integerarray_mappings <- mappings(:integerarray, params),
            booleanarray_mappings <- mappings(:booleanarray, params),
            longintegerarray_mappings <- mappings(:longintegerarray, params),
            stringarray_mappings <- mappings(:stringarray, params),
            binaryblobarray_mappings <- mappings(:binaryblobarray, params),
            datetimearray_mappings <- mappings(:datetimearray, params),
            all_mappings =
              Enum.concat([
                double_mappings,
                integer_mappings,
                boolean_mappings,
                longinteger_mappings,
                string_mappings,
                binaryblob_mappings,
                datetime_mappings,
                doublearray_mappings,
                integerarray_mappings,
                booleanarray_mappings,
                longintegerarray_mappings,
                stringarray_mappings,
                binaryblobarray_mappings,
                datetimearray_mappings
              ]),
            endpoints <- shuffle(all_mappings) do
      endpoints
    end
  end

  defp mappings(value_type, common_params) do
    params = [
      {:value_type, value_type},
      {:endpoint, repeatedly(fn -> "/uniq/endpoint#{System.unique_integer([:positive])}" end)}
      | common_params
    ]

    MappingGenerator.mapping(params)
    |> list_of(min_length: 1)
  end

  defp get_interface_descriptors(realm_name, interfaces) do
    for interface <- interfaces do
      case InterfaceQueries.fetch_interface_descriptor(
             realm_name,
             interface.name,
             interface.major_version
           ) do
        {:ok, interface_descriptor} ->
          interface_descriptor

        {:error, :interface_not_found} ->
          raise "Interface not found: #{interface.name} v#{interface.major_version} in #{realm_name}"

        {:error, reason} ->
          raise "Failed to fetch interface descriptor: #{interface.name} v#{interface.major_version} in #{realm_name}, reason: #{inspect(reason)}"
      end
    end
  end

  defp get_endpoints_by_interface_id(realm_name, interface_descriptors) do
    interface_ids = interface_descriptors |> Enum.map(& &1.interface_id)

    Repo.all(Endpoint, prefix: Realm.keyspace_name(realm_name))
    |> Enum.group_by(& &1.interface_id)
    |> Map.take(interface_ids)
  end

  defp new_interfaces(interface_gen, previous_interfaces, type) do
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

    case type do
      :single -> interface_gen |> Enum.at(0)
      :list -> interface_gen |> list_of(min_length: 1) |> Enum.at(0) |> cleanup_duplicates()
    end
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
end
