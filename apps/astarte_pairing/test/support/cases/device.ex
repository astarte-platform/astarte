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

  import Astarte.Helpers.Device

  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  alias Astarte.Generators.Interface, as: InterfaceGenerator
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

    interfaces = InterfaceGenerator.interface_list() |> Enum.at(0)

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
