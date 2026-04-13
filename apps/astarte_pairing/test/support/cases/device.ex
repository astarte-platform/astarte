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

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  alias Astarte.Helpers.Device, as: DeviceHelper
  alias Astarte.Pairing.CredentialsSecret

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  setup_all %{realm_name: realm_name} do
    credentials_secret = CredentialsSecret.generate()
    inhibited_credentials_secret = CredentialsSecret.generate()
    confirmed_credentials_secret = CredentialsSecret.generate()
    unconfirmed_credentials_secret = CredentialsSecret.generate()
    unconfirmed_credentials_secret2 = CredentialsSecret.generate()
    unregistered_credentials_secret = CredentialsSecret.generate()

    interfaces = interfaces()

    device = %{base_device(interfaces) | credentials_secret: credentials_secret}

    unregistered_device = %{
      base_device(interfaces)
      | credentials_secret: unregistered_credentials_secret
    }

    inhibited_device =
      %{
        base_device(interfaces)
        | inhibit_credentials_request: true,
          credentials_secret: inhibited_credentials_secret
      }

    unconfirmed_device = %{
      base_device(interfaces)
      | first_credentials_request: nil,
        inhibit_credentials_request: false,
        credentials_secret: unconfirmed_credentials_secret
    }

    unconfirmed_device2 = %{
      base_device(interfaces)
      | first_credentials_request: nil,
        inhibit_credentials_request: false,
        credentials_secret: unconfirmed_credentials_secret2
    }

    confirmed_device = %{
      base_device(interfaces)
      | first_credentials_request: DateTime.now!("Etc/UTC"),
        inhibit_credentials_request: false,
        credentials_secret: confirmed_credentials_secret
    }

    for interface <- interfaces, do: insert_interface_cleanly(realm_name, interface)

    interface_descriptors = get_interface_descriptors(realm_name, interfaces)
    endpoints = get_endpoints_by_interface_id(realm_name, interface_descriptors)

    interfaces =
      interfaces
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

    %{
      interfaces: interfaces,
      device: device,
      unconfirmed_device: unconfirmed_device,
      unconfirmed_device2: unconfirmed_device2,
      confirmed_device: confirmed_device,
      inhibited_device: inhibited_device,
      unregistered_device: unregistered_device,
      interface_descriptors: interface_descriptors,
      endpoints: endpoints
    }
  end

  defp base_device(interfaces),
    do: DeviceHelper.sample_device(interfaces) |> Map.put(:credentials_secret, nil)

  defp interfaces do
    interface_specs = [
      fn acc -> new_interfaces(individual_datastream(:device), acc) end,
      fn acc -> new_interfaces(individual_datastream(:server), acc) end,
      fn acc -> new_interfaces(object_datastream(:device), acc) end,
      fn acc -> new_interfaces(object_datastream(:server), acc) end,
      fn acc -> new_interfaces(properties(:device), acc) end,
      fn acc -> new_interfaces(properties(:server), acc) end,
      fn acc -> new_interfaces(other(), acc) end
    ]

    Enum.reduce(interface_specs, [], fn gen_fn, acc_interfaces ->
      Enum.concat(acc_interfaces, gen_fn.(acc_interfaces))
    end)
  end

  defp individual_datastream(ownership) do
    InterfaceGenerator.interface(
      ownership: ownership,
      aggregation: :individual,
      type: :datastream
    )
  end

  defp object_datastream(ownership) do
    InterfaceGenerator.interface(ownership: ownership, aggregation: :object, type: :datastream)
  end

  defp properties(ownership) do
    InterfaceGenerator.interface(ownership: ownership, type: :properties)
  end

  defp other, do: InterfaceGenerator.interface()

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

    interface_gen |> list_of(min_length: 1) |> Enum.at(0) |> cleanup_duplicates()
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
