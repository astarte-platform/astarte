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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.DeviceTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device

  use Astarte.Cases.DataUpdater

  use ExUnitProperties
  use Mimic

  @moduletag timeout: 180_000

  import Astarte.InterfaceUpdateGenerators
  import Ecto.Query

  alias Astarte.Core.Device
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.Mapping.ValueType
  alias Astarte.DataAccess.Devices.Device, as: DatabaseDevice
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.RPC.VMQPlugin
  alias Astarte.Helpers.Database

  @timestamp_us_x_10 Database.make_timestamp("2025-05-14T14:00:32+00:00")

  setup_all :populate_interfaces

  describe "ask_clean_session/2" do
    test "disconnects device and clears cache on successful disconnect", %{
      realm_name: realm_name,
      state: state
    } do
      # Successfully disconnected
      Mimic.expect(VMQPlugin, :disconnect, fn _client_id, _discard_state -> :ok end)

      {:ok, new_state} = Core.Device.ask_clean_session(state, @timestamp_us_x_10)

      assert read_device_empty_cache(realm_name, state.device_id) == true
      assert new_state.connected == false
    end

    test "clears cache and marks device disconnected if already disconnected", %{
      realm_name: realm_name,
      state: state
    } do
      # Not found means it was already disconnected, succeed anyway
      Mimic.expect(VMQPlugin, :disconnect, fn _client_id, _discard_state ->
        {:error, :not_found}
      end)

      {:ok, new_state} = Core.Device.ask_clean_session(state, @timestamp_us_x_10)

      assert read_device_empty_cache(realm_name, state.device_id) == true
      assert new_state.connected == false
    end

    test "returns error and clears cache on disconnect failure", %{
      realm_name: realm_name,
      state: state
    } do
      # Some other error, return it
      Mimic.expect(VMQPlugin, :disconnect, fn _client_id, _discard_state ->
        {:error, :timeout}
      end)

      assert {:error, :clean_session_failed} =
               Core.Device.ask_clean_session(state, @timestamp_us_x_10)

      assert read_device_empty_cache(realm_name, state.device_id) == true
    end
  end

  describe "prune_device_properties/3" do
    property "keeps only specified properties when decoded_payload is not empty", context do
      %{
        state: state,
        interfaces: interfaces,
        interface_descriptors: interface_descriptors,
        realm_name: realm_name,
        device: device
      } = context

      descriptors_map =
        interface_descriptors
        |> Map.new(fn desc ->
          {desc.interface_id, desc}
        end)

      valid_interfaces =
        interfaces
        |> Enum.filter(&(&1.type == :properties and &1.ownership == :device))

      check all interfaces <- list_of(member_of(valid_interfaces), min_length: 1),
                interfaces = Enum.uniq_by(interfaces, &{&1.name, &1.major_version}),
                mapping_updates =
                  Map.new(interfaces, fn interface ->
                    {interface, list_of(valid_mapping_update_for(interface))}
                  end),
                mapping_updates <- fixed_map(mapping_updates),
                mapping_updates_list =
                  Enum.flat_map(mapping_updates, fn {interface, updates} ->
                    updates
                    |> Enum.uniq_by(& &1.path)
                    |> Enum.map(&{interface, &1})
                  end),
                split_size <- integer(0..Enum.count(mapping_updates_list)),
                mapping_updates_list <- shuffle(mapping_updates_list),
                {to_keep, to_delete} = Enum.split(mapping_updates_list, split_size),
                decoded_payload =
                  to_keep
                  |> Enum.map_join(";", fn {interface, mapping_update} ->
                    interface.name <> mapping_update.path
                  end) do
        Enum.each(mapping_updates_list, fn {interface, mapping_update} ->
          descriptor = Map.fetch!(descriptors_map, interface.interface_id)
          Database.insert_values(realm_name, device, interface, descriptor, [mapping_update])
        end)

        :ok = Core.Device.prune_device_properties(state, decoded_payload, DateTime.utc_now())

        keyspace = Realm.keyspace_name(realm_name)

        properties =
          from("individual_properties", select: [:path, :device_id, :interface_id])
          |> Repo.all(prefix: keyspace)

        Enum.each(to_keep, fn {interface, mapping_update} ->
          expected_kept = %{
            path: mapping_update.path,
            device_id: device.device_id,
            interface_id: interface.interface_id
          }

          assert expected_kept in properties
        end)

        Enum.each(to_delete, fn {interface, mapping_update} ->
          expected_pruned = %{
            path: mapping_update.path,
            device_id: device.device_id,
            interface_id: interface.interface_id
          }

          assert expected_pruned not in properties
        end)

        Enum.each(mapping_updates_list, fn {interface, mapping_update} ->
          Database.delete_values(realm_name, device, interface, [mapping_update])
        end)
      end
    end

    test "does not remove properties of server owned interfaces", %{
      state: state,
      realm_name: realm_name,
      device: device,
      individual_properties_server_interface: interface,
      registered_paths: registered_paths
    } do
      paths = registered_paths |> Map.fetch!({interface.name, interface.major_version})

      :ok = Core.Device.prune_device_properties(state, "", DateTime.utc_now())

      {:ok, interface_descriptor} =
        InterfaceQueries.fetch_interface_descriptor(
          realm_name,
          interface.name,
          interface.major_version
        )

      expected_paths = Enum.sort(paths)

      actual_paths =
        interface.mappings
        |> Enum.map(& &1.endpoint_id)
        |> Enum.flat_map(
          &Queries.all_device_owned_property_endpoint_paths!(
            realm_name,
            device.device_id,
            interface_descriptor,
            &1
          )
        )
        |> Enum.sort()

      assert actual_paths == expected_paths
    end
  end

  describe "resend_all_properties/1" do
    test "returns error when interface cache miss occurs", %{state: state} do
      # Simulate a cache miss
      Mimic.expect(Core.Interface, :maybe_handle_cache_miss, fn _maybe_descriptor,
                                                                _interface,
                                                                _state_acc ->
        {:error, :interface_loading_failed}
      end)

      assert {:error, :sending_properties_to_interface_failed} ==
               Core.Device.resend_all_properties(state)
    end

    @tag :regression
    test "sends properties with the correct bson type", context do
      %{state: state, realm_name: realm_name, server_property_with_all_endpoint_types: interface} =
        context

      # we only need this one interface for the test
      state = put_in(state.introspection, %{interface.name => interface.major_version})
      encoded_device_id = Device.encode_device_id(state.device_id)
      {:ok, automaton} = EndpointsAutomaton.build(interface.mappings)

      # one call for each mapping
      calls = Enum.count(interface.mappings)
      topic_prefix = "#{realm_name}/#{encoded_device_id}/#{interface.name}"

      Mimic.expect(VMQPlugin, :publish, calls, fn topic, bson, qos ->
        path = String.replace_prefix(topic, topic_prefix, "")
        {:ok, endpoint} = EndpointsAutomaton.resolve_path(path, automaton)

        mapping =
          Enum.find(interface.mappings, &(&1.endpoint == endpoint)) || flunk("invalid endpoint")

        value = bson |> Cyanide.decode!() |> Map.fetch!("v")

        assert qos == 2
        assert String.starts_with?(topic, topic_prefix)
        assert valid_value_type?(mapping.value_type, value)

        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      Core.Device.resend_all_properties(state)
    end
  end

  describe "set_device_disconnected/2" do
    @tag :regression
    test "does not re-insert a deleted device", %{state: state} do
      device_id = DeviceGenerator.id() |> Enum.at(0)

      # Simulate a non-existing device by changing the id
      state = %{state | device_id: device_id, connected: false}
      timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond) |> then(&(&1 * 10))

      assert Core.Device.set_device_disconnected(state, timestamp)

      assert {:ok, false} = Queries.check_device_exists(state.realm, device_id)
    end
  end

  defp read_device_empty_cache(realm_name, device_id) do
    Repo.get!(DatabaseDevice, device_id, prefix: Realm.keyspace_name(realm_name))
    |> Map.fetch!(:pending_empty_cache)
  end

  defp valid_value_type?(:binaryblob, value), do: is_struct(value, Cyanide.Binary)
  defp valid_value_type?(:datetime, value), do: is_struct(value, DateTime)

  defp valid_value_type?(:binaryblobarray, value),
    do: Enum.all?(value, &valid_value_type?(:binaryblob, &1))

  defp valid_value_type?(:datetimearray, value),
    do: Enum.all?(value, &valid_value_type?(:datetime, &1))

  defp valid_value_type?(value_type, value),
    do: ValueType.validate_value(value_type, value) == :ok
end
