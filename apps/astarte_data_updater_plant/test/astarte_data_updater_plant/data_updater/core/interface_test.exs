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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.InterfaceTest do
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.Helpers
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataAccess.Realms.Interface, as: InterfaceData
  alias Astarte.DataAccess.Mappings
  alias Astarte.Core.Interface
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.DataUpdaterPlant.DataUpdater.Core

  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties

  import Ecto.Query
  import Mimic
  import Astarte.InterfaceUpdateGenerators

  @interface_lifespan_decimicroseconds 60 * 10 * 1000 * 10000

  setup_all %{realm_name: realm_name, device: device} do
    {:ok, message_tracker} = DataUpdater.fetch_message_tracker(realm_name, device.encoded_id)

    {:ok, data_updater} =
      DataUpdater.fetch_data_updater_process(
        realm_name,
        device.encoded_id,
        message_tracker,
        true
      )

    Astarte.DataAccess.Config
    |> allow(self(), data_updater)

    :ok = GenServer.call(data_updater, :start)

    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    %{state: state, data_updater: data_updater, messagte_tracker: message_tracker}
  end

  describe "maybe_handle_cache_miss/3" do
    test "updates device state on miss", context do
      %{
        realm_name: realm_name,
        state: state,
        interfaces: interfaces
      } = context

      keyspace = Realm.keyspace_name(realm_name)

      %{last_seen_message: last_seen_message} = state

      interface = Enum.random(interfaces)

      %Interface{
        name: interface_name,
        major_version: interface_major
      } = interface

      query =
        from InterfaceData,
          where: [name: ^interface_name],
          select: [:interface_id]

      {:ok, interface} = Repo.fetch_one(query, prefix: keyspace)
      interface_id = interface.interface_id

      # Cache miss, the interface descriptor is nil
      {:ok, descriptor, new_state} =
        Core.Interface.maybe_handle_cache_miss(nil, interface_name, state)

      expiry = last_seen_message + @interface_lifespan_decimicroseconds

      {:ok, mappings} = Mappings.fetch_interface_mappings(realm_name, interface_id)
      mappings_map = Map.new(mappings, &{&1.endpoint_id, &1})

      assert %InterfaceDescriptor{
               name: ^interface_name,
               major_version: ^interface_major
             } = descriptor

      assert %{^interface_name => ^descriptor} = new_state.interfaces
      assert %{^interface_id => ^interface_name} = new_state.interface_ids_to_name

      assert {expiry, interface_name} in new_state.interfaces_by_expiry

      assert new_state.mappings
             |> Map.delete(nil)
             |> Map.equal?(mappings_map)
    end
  end

  describe "Interfaces" do
    setup %{interfaces: interfaces, state: state} do
      new_state =
        Enum.reduce(interfaces, state, fn interface, state ->
          {:ok, _descriptor, new_state} =
            Core.Interface.maybe_handle_cache_miss(
              Map.get(state.interfaces, interface.name),
              interface.name,
              state
            )

          new_state
        end)

      %{state: new_state}
    end

    property "prune_interface/4 removes properties of device owned interfaces", context do
      %{
        state: state,
        interfaces: interfaces,
        realm_name: realm_name,
        device: device
      } = context

      valid_interfaces =
        interfaces |> Enum.filter(&(&1.type == :properties and &1.ownership == :device))

      check all interface <- member_of(valid_interfaces),
                mapping_update <- valid_mapping_update_for(interface) do
        Helpers.Database.insert_values(realm_name, device, interface, mapping_update)

        keyspace = Realm.keyspace_name(realm_name)

        assert {:ok, _new_state} =
                 Core.Interface.prune_interface(
                   state,
                   interface.name,
                   MapSet.new(),
                   DateTime.utc_now()
                 )

        properties =
          from("individual_properties", select: [:path, :device_id, :interface_id])
          |> Repo.all(prefix: keyspace)

        expected_property = %{
          path: mapping_update.path,
          device_id: device.device_id,
          interface_id: interface.interface_id
        }

        assert expected_property not in properties
      end
    end

    property "resolve_path/3 finds endpoint from interface descriptor and mappings",
             context do
      %{
        interfaces: interfaces,
        state: state
      } = context

      check all interface <- member_of(interfaces),
                mapping_update <- valid_mapping_update_for(interface) do
        descriptor = state.interfaces[interface.name]

        {:ok, endpoint} =
          Core.Interface.resolve_path(mapping_update.path, descriptor, state.mappings)

        assert matches?(endpoint.endpoint, mapping_update.path, interface.aggregation)
      end
    end

    property "extract_expected_types/3 extracts types from endpoint", context do
      %{
        interfaces: interfaces,
        state: state,
        realm_name: realm_name
      } = context

      check all interface <- member_of(interfaces),
                mapping <- member_of(interface.mappings),
                path <- path_from_endpoint(mapping.endpoint) do
        descriptor = state.interfaces[interface.name]

        keyspace = Realm.keyspace_name(realm_name)

        query =
          from i in Endpoint,
            hints: ["ALLOW FILTERING"],
            where: [interface_id: ^interface.interface_id, endpoint: ^mapping.endpoint],
            select: [:value_type]

        endpoint = Repo.one(query, prefix: keyspace)

        expected_type =
          Core.Interface.extract_expected_types(
            path,
            descriptor,
            endpoint,
            state.mappings
          )

        assert valid_type?(mapping, expected_type, interface.aggregation)
      end
    end

    property "forget_interfaces/2 removes interfaces from state cache", context do
      %{
        interfaces: interfaces,
        state: state
      } = context

      check all interfaces_to_drop <- list_of(member_of(interfaces)) do
        interfaces_to_drop_names = interfaces_to_drop |> Enum.map(& &1.name)
        new_state = Core.Interface.forget_interfaces(state, interfaces_to_drop_names)

        interface_names = new_state.interfaces |> Map.keys()
        interface_ids = new_state.interface_ids_to_name |> Map.keys()
        endpoint_ids = new_state.mappings |> Map.keys()

        assert Enum.all?(interfaces_to_drop, fn interface ->
                 interface.name not in interface_names
               end)

        assert Enum.all?(interfaces_to_drop, fn interface ->
                 interface.interface_id not in interface_ids
               end)

        assert Enum.all?(interfaces_to_drop, fn interface ->
                 Enum.all?(interface.mappings, fn mapping ->
                   mapping.endpoint_id not in endpoint_ids
                 end)
               end)
      end
    end
  end

  defp valid_type?(mapping, expected_type, :individual), do: mapping.value_type == expected_type

  defp valid_type?(mapping, expected_type, :object) do
    key = mapping.endpoint |> String.split("/") |> List.last()
    value = mapping.value_type

    %{key => value} == expected_type
  end

  defp matches?(endpoint, path, aggregation) do
    endpoint_tokens = endpoint_tokens(endpoint, aggregation)
    path_tokens = String.split(path, "/", trim: true)

    length(endpoint_tokens) == length(path_tokens) and
      Enum.zip(endpoint_tokens, path_tokens)
      |> Enum.all?(&token_match?/1)
  end

  defp endpoint_tokens(string, :object),
    do:
      String.split(string, "/", trim: true)
      |> List.delete_at(-1)

  defp endpoint_tokens(string, :individual), do: String.split(string, "/", trim: true)

  defp token_match?({endpoint_token, path_token}) do
    Astarte.Core.Mapping.is_placeholder?(endpoint_token) or endpoint_token == path_token
  end
end
