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
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  use ExUnit.CaseTemplate
  use ExUnitProperties

  import Astarte.Helpers.Device
  import Ecto.Query

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  setup_all %{realm_name: realm_name} do
    interfaces_data = interfaces()
    device = DeviceGenerator.device(interfaces: interfaces_data.interfaces) |> Enum.at(0)

    Enum.each(interfaces_data.interfaces, &insert_interface_cleanly(realm_name, &1))

    updated_interfaces = update_interfaces_id(realm_name, interfaces_data.interfaces)

    insert_device_cleanly(realm_name, device, updated_interfaces)

    interfaces_data
    |> Map.put(:interfaces, updated_interfaces)
    |> Map.put(:device, device)
  end

  defp update_interfaces_id(realm_name, interfaces) do
    keyspace = Realm.keyspace_name(realm_name)
    chunks = interfaces |> Enum.chunk_every(10)

    interface_ids =
      for chunk <- chunks do
        {names, major_versions} =
          chunk
          |> Enum.map(&{&1.name, &1.major_version})
          |> Enum.unzip()

        query =
          from i in Interface,
            where: i.name in ^names and i.major_version in ^major_versions,
            select: [:interface_id, :name, :major_version]

        Repo.all(query, prefix: keyspace)
      end
      |> Enum.concat()

    Enum.map(interfaces, fn interface ->
      db_interface =
        Enum.find(interface_ids, interface.interface_id, fn db_interface ->
          db_interface.name == interface.name and
            db_interface.major_version == interface.major_version
        end)

      if db_interface == nil, do: raise("Interface not found!")

      interface
      |> Map.put(:interface_id, db_interface.interface_id)
    end)
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
end
