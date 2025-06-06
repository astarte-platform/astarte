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
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

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
      device: device
    } = context

    random_interfaces =
      interfaces
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

    interface_data =
      for interface <- interfaces_with_data, into: %{} do
        interface_data = populate(realm_name, device, interface)
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
      individual_properties_server_interface: individual_properties_server
    }
  end

  defp populate(realm_name, device, interface) do
    mapping_update = valid_mapping_update_for(interface)

    values =
      list_of(mapping_update, length: 100..10_000)
      |> Enum.at(0)

    timings = insert_values(realm_name, device, interface, values)
    paths = MapSet.new(values, & &1.path)

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
    # make sure we have at least 1 interface of each type
    individual_datastream_device =
      list_of(individual_datastream(:device), min_length: 1) |> Enum.at(0)

    individual_datastream_server =
      list_of(individual_datastream(:server), min_length: 1) |> Enum.at(0)

    object_datastream_server = list_of(object_datastream(:server), min_length: 1) |> Enum.at(0)
    object_datastream_device = list_of(object_datastream(:device), min_length: 1) |> Enum.at(0)
    properties_device = list_of(properties(:device), min_length: 1) |> Enum.at(0)
    properties_server = list_of(properties(:server), min_length: 1) |> Enum.at(0)

    other_interfaces = list_of(InterfaceGenerator.interface(), min_length: 1) |> Enum.at(0)

    all_interfaces =
      [
        individual_datastream_device,
        individual_datastream_server,
        object_datastream_device,
        object_datastream_server,
        properties_device,
        properties_server,
        other_interfaces
      ]
      |> Enum.concat()

    %{
      interfaces: all_interfaces
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

  defp get_interface_descriptors(realm_name, interfaces) do
    for interface <- interfaces do
      {:ok, interface_descriptor} =
        InterfaceQueries.fetch_interface_descriptor(
          realm_name,
          interface.name,
          interface.major_version
        )

      interface_descriptor
    end
  end

  defp get_endpoints_by_interface_id(realm_name, interface_descriptors) do
    interface_ids = interface_descriptors |> Enum.map(& &1.interface_id)

    Repo.all(Endpoint, prefix: Realm.keyspace_name(realm_name))
    |> Enum.group_by(& &1.interface_id)
    |> Map.take(interface_ids)
  end
end
