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
  @moduledoc false
  use ExUnit.CaseTemplate
  use ExUnitProperties

  import Astarte.Helpers.Device

  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.Pairing.CredentialsSecret

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  setup_all %{realm_name: realm_name} do
    interfaces_data = interfaces()
    credentials_secret = CredentialsSecret.generate()
    inhibited_credentials_secret = CredentialsSecret.generate()
    confirmed_credentials_secret = CredentialsSecret.generate()
    unconfirmed_credentials_secret = CredentialsSecret.generate()
    unconfirmed_credentials_secret2 = CredentialsSecret.generate()
    unregistered_credentials_secret = CredentialsSecret.generate()

    device =
      DeviceGenerator.device(interfaces: interfaces_data.interfaces)
      |> resize(10)
      |> Enum.at(0)
      |> Map.put(:credentials_secret, credentials_secret)

    unregistered_device =
      DeviceGenerator.device(interfaces: interfaces_data.interfaces)
      |> resize(10)
      |> Enum.at(0)
      |> Map.put(:credentials_secret, unregistered_credentials_secret)

    inhibited_device =
      DeviceGenerator.device(interfaces: interfaces_data.interfaces)
      |> resize(10)
      |> Enum.at(0)
      |> Map.put(:inhibit_credentials_request, true)
      |> Map.put(:credentials_secret, inhibited_credentials_secret)

    unconfirmed_device =
      DeviceGenerator.device(interfaces: interfaces_data.interfaces)
      |> resize(10)
      |> Enum.at(0)
      |> Map.put(:first_credentials_request, nil)
      |> Map.put(:inhibit_credentials_request, false)
      |> Map.put(:credentials_secret, unconfirmed_credentials_secret)

    unconfirmed_device2 =
      DeviceGenerator.device(interfaces: interfaces_data.interfaces)
      |> resize(10)
      |> Enum.at(0)
      |> Map.put(:first_credentials_request, nil)
      |> Map.put(:inhibit_credentials_request, false)
      |> Map.put(:credentials_secret, unconfirmed_credentials_secret2)

    confirmed_device =
      DeviceGenerator.device(interfaces: interfaces_data.interfaces)
      |> resize(10)
      |> Enum.at(0)
      |> Map.put(:first_credentials_request, DateTime.now!("Etc/UTC"))
      |> Map.put(:inhibit_credentials_request, false)
      |> Map.put(:credentials_secret, confirmed_credentials_secret)

    Enum.each(interfaces_data.interfaces, &insert_interface_cleanly(realm_name, &1))

    interface_descriptors = get_interface_descriptors(realm_name, interfaces_data.interfaces)
    endpoints = get_endpoints_by_interface_id(realm_name, interface_descriptors)

    interfaces =
      interfaces_data.interfaces
      |> update_interfaces_id(interface_descriptors)
      |> update_endpoints_ids(endpoints)

    insert_device_cleanly(realm_name, device, interfaces, credentials_secret)

    insert_device_cleanly(
      realm_name,
      unconfirmed_device,
      interfaces,
      unconfirmed_credentials_secret
    )

    insert_device_cleanly(
      realm_name,
      unconfirmed_device2,
      interfaces,
      unconfirmed_credentials_secret
    )

    insert_device_cleanly(realm_name, confirmed_device, interfaces, confirmed_credentials_secret)
    insert_device_cleanly(realm_name, inhibited_device, interfaces, inhibited_credentials_secret)

    inhibited_device =
      inhibited_device
      |> Map.put(:credentials_secret, inhibited_credentials_secret)

    device =
      device
      |> Map.put(:credentials_secret, credentials_secret)

    confirmed_device =
      confirmed_device
      |> Map.put(:credentials_secret, confirmed_credentials_secret)

    unconfirmed_device =
      unconfirmed_device
      |> Map.put(:credentials_secret, unconfirmed_credentials_secret)

    unconfirmed_device2 =
      unconfirmed_device2
      |> Map.put(:credentials_secret, unconfirmed_credentials_secret2)

    interfaces_data
    |> Map.put(:interfaces, interfaces)
    |> Map.put(:device, device)
    |> Map.put(:unconfirmed_device, unconfirmed_device)
    |> Map.put(:unconfirmed_device2, unconfirmed_device2)
    |> Map.put(:confirmed_device, confirmed_device)
    |> Map.put(:inhibited_device, inhibited_device)
    |> Map.put(:unregistered_device, unregistered_device)
    |> Map.put(:interface_descriptors, interface_descriptors)
    |> Map.put(:endpoints, endpoints)
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
