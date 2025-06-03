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

defmodule Astarte.DataUpdaterPlant.DataUpdater.QueriesTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties
  use Mimic

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Generators.Realm, as: RealmGenerator
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Devices.Device, as: DatabaseDevice
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Interface, as: DatabaseInterface
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries

  import ExUnit.CaptureLog
  import Ecto.Query

  setup_all :populate_interfaces

  describe "set_pending_empty_cache/3" do
    setup %{realm_name: realm_name, astarte_instance_id: astarte_instance_id} do
      device_id = Device.random_device_id()

      on_exit(fn ->
        setup_database_access(astarte_instance_id)
        remove_device(device_id, realm_name)
      end)

      insert_device(device_id, realm_name)

      %{device_id: device_id}
    end

    test "sets the pending empty cache to the given value", context do
      %{realm_name: realm_name, device_id: device_id} = context
      pending_empty_cache = boolean() |> Enum.at(0)

      assert Queries.set_pending_empty_cache(realm_name, device_id, pending_empty_cache) == :ok
      assert read_device_empty_cache(realm_name, device_id) == pending_empty_cache
    end

    @tag skip: "broken_safe"
    test "logs in case of Xandra.Error", context do
      %{realm_name: realm_name, device_id: device_id} = context
      pending_empty_cache = boolean() |> Enum.at(0)

      Xandra
      |> expect(:execute, fn _conn, _query, _params, _opts ->
        {:error, %Xandra.Error{message: "xandra error", reason: :error_reason}}
      end)

      {result, log} =
        with_log(fn ->
          Queries.set_pending_empty_cache(realm_name, device_id, pending_empty_cache)
        end)

      assert log =~ "Cannot set pending empty cache"
      assert {:error, %Xandra.Error{}} = result
    end

    @tag skip: "broken_safe"
    test "logs in case of Xandra.ConnectionError", context do
      %{realm_name: realm_name, device_id: device_id} = context
      pending_empty_cache = boolean() |> Enum.at(0)

      Xandra
      |> expect(:execute, fn _conn, _query, _params, _opts ->
        {:error, %Xandra.ConnectionError{action: "connection error", reason: :error_reason}}
      end)

      {result, log} =
        with_log(fn ->
          Queries.set_pending_empty_cache(realm_name, device_id, pending_empty_cache)
        end)

      assert log =~ "Cannot set pending empty cache"
      assert {:error, %Xandra.ConnectionError{}} = result
    end
  end

  describe "register_device_with_interface/4" do
    setup :select_interface_for_device_with_interface

    test "registers the device in the database", context do
      %{realm_name: realm_name, interface: interface, device: device} = context

      assert Queries.register_device_with_interface(
               realm_name,
               device.device_id,
               interface.name,
               interface.major_version
             ) == :ok

      assert registered_by_interface?(realm_name, device, interface)
      assert registered_on_interface?(realm_name, device, interface)
    end

    @tag skip: "broken_safe"
    test "logs in case of Xandra.Error", context do
      %{realm_name: realm_name, interface: interface, device: device} = context

      Xandra
      |> expect(:execute, fn _conn, _query, _params, _opts ->
        {:error, %Xandra.Error{message: "xandra error", reason: :error_reason}}
      end)

      {result, log} =
        with_log(fn ->
          Queries.register_device_with_interface(
            realm_name,
            device.device_id,
            interface.name,
            interface.major_version
          )
        end)

      assert log =~ "cannot register device-interface pair"
      assert {:error, %Xandra.Error{}} = result
    end

    @tag skip: "broken_safe"
    test "logs in case of Xandra.ConnectionError", context do
      %{realm_name: realm_name, interface: interface, device: device} = context

      Xandra
      |> expect(:execute, fn _conn, _query, _params, _opts ->
        {:error, %Xandra.ConnectionError{action: "connection error", reason: :error_reason}}
      end)

      {result, log} =
        with_log(fn ->
          Queries.register_device_with_interface(
            realm_name,
            device.device_id,
            interface.name,
            interface.major_version
          )
        end)

      assert log =~ "cannot register device-interface pair"
      assert {:error, %Xandra.ConnectionError{}} = result
    end
  end

  describe "retrieve_property_values/4" do
    property "returns the saved properties for the selected mapping", context do
      %{interfaces_with_data: interfaces, device: device, realm_name: realm_name} = context
      interfaces = interfaces |> Enum.filter(&(&1.type == :properties))
      descriptors = interface_descriptor_map(realm_name, interfaces)

      check all interface <- member_of(interfaces),
                descriptor = descriptors[interface],
                mapping <- member_of(interface.mappings),
                data_column =
                  mapping.value_type
                  |> CQLUtils.type_to_db_column_name()
                  |> String.to_existing_atom() do
        result =
          Queries.retrieve_property_values(realm_name, device.id, descriptor, mapping)

        assert is_list(result)

        for property_value <- result do
          assert Map.has_key?(property_value, :path)
          assert Map.has_key?(property_value, data_column)
        end
      end
    end
  end

  describe "retrieve_realms!/0" do
    setup do
      astarte_instance_id = "custom#{System.unique_integer([:positive])}"

      realm_names =
        list_of(RealmGenerator.realm_name(), min_length: 5)
        |> resize(5)
        |> Enum.at(0)
        |> Enum.sort()
        |> Enum.dedup()

      setup_instance(astarte_instance_id, realm_names)

      %{astarte_instance_id: astarte_instance_id, realm_names: realm_names}
    end

    test "returns the list of realms", %{realm_names: expected_realms} do
      realms = Queries.retrieve_realms!() |> Enum.map(& &1["realm_name"]) |> Enum.sort()
      assert realms == expected_realms
    end
  end

  describe "retrieve_devices_waiting_to_start_deletion!/1" do
    setup %{realm_name: realm_name} do
      result = populate_deletion_in_progress(realm_name)

      %{deletion_in_progress: result}
    end

    test "returns the status of the devices awaiting deletion", context do
      %{deletion_in_progress: expected_result, realm_name: realm_name} = context

      for entry <- Queries.retrieve_devices_waiting_to_start_deletion!(realm_name) do
        assert %{
                 "device_id" => device_id,
                 "vmq_ack" => vmq_ack,
                 "dup_start_ack" => dup_start_ack,
                 "dup_end_ack" => dup_end_ack
               } = entry

        %{
          device_id: ^device_id,
          vmq_ack: expected_vmq_ack,
          dup_start_ack: expected_dup_start_ack,
          dup_end_ack: expected_dup_end_ack
        } =
          Enum.find(expected_result, &(&1.device_id == device_id)) ||
            flunk("device not found: #{inspect(device_id)}")

        assert vmq_ack == expected_vmq_ack
        assert dup_start_ack == expected_dup_start_ack
        assert dup_end_ack == expected_dup_end_ack
      end
    end
  end

  defp populate_deletion_in_progress(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    deletion_in_progress_entries =
      list_of(deletion_in_progress_entry(), min_length: 5)
      |> resize(5)
      |> Enum.at(0)
      |> Enum.sort()
      |> Enum.uniq_by(& &1.device_id)

    for entry <- deletion_in_progress_entries, do: Repo.insert!(entry, prefix: keyspace)

    deletion_in_progress_entries
  end

  defp deletion_in_progress_entry do
    gen all device_id <- DeviceGenerator.id(),
            vmq_ack <- boolean(),
            dup_start_ack <- boolean(),
            dup_end_ack <- if(dup_start_ack, do: boolean(), else: false) do
      %DeletionInProgress{
        device_id: device_id,
        vmq_ack: vmq_ack,
        dup_start_ack: dup_start_ack,
        dup_end_ack: dup_end_ack
      }
    end
  end

  defp read_device_empty_cache(realm_name, device_id) do
    Repo.get!(DatabaseDevice, device_id, prefix: Realm.keyspace_name(realm_name))
    |> Map.fetch!(:pending_empty_cache)
  end

  defp interface_descriptor_map(realm_name, interfaces) do
    keyspace = Realm.keyspace_name(realm_name)

    descriptors =
      interfaces
      |> Enum.chunk_every(10)
      |> Enum.map(fn interface_chunk ->
        names = interface_chunk |> Enum.map(& &1.name) |> Enum.uniq()
        majors = interface_chunk |> Enum.map(& &1.major_version) |> Enum.uniq()

        from(i in DatabaseInterface, where: i.name in ^names and i.major_version in ^majors)
        |> Repo.all(prefix: keyspace)
      end)
      |> Enum.concat()
      |> Enum.map(&InterfaceDescriptor.from_db_result/1)
      |> Enum.map(fn {:ok, descriptor} -> descriptor end)

    interfaces
    |> Map.new(fn interface ->
      descriptor =
        descriptors
        |> Enum.find(&(&1.name == interface.name and &1.major_version == interface.major_version))

      _ =
        descriptor || flunk("interface descriptor not found for interface #{inspect(interface)}")

      {interface, descriptor}
    end)
  end

  defp select_interface_for_device_with_interface(context) do
    %{
      realm_name: realm_name,
      astarte_instance_id: astarte_instance_id,
      device: device,
      interfaces: interfaces
    } = context

    interface = member_of(interfaces) |> Enum.at(0)

    on_exit(fn ->
      setup_database_access(astarte_instance_id)
      keyspace = Realm.keyspace_name(realm_name)

      by_interface = %KvStore{
        group: "devices-by-interface-#{interface.name}-v#{interface.major_version}",
        key: device.encoded_id
      }

      on_interface = %KvStore{
        group: "devices-with-data-on-interface-#{interface.name}-v#{interface.major_version}",
        key: device.encoded_id
      }

      Repo.delete(by_interface, prefix: keyspace)
      Repo.delete(on_interface, prefix: keyspace)
    end)

    %{interface: interface}
  end

  defp registered_by_interface?(realm_name, device, interface) do
    group = "devices-by-interface-#{interface.name}-v#{interface.major_version}"
    key = device.encoded_id

    case KvStore.fetch_value(group, key, :binary, prefix: Realm.keyspace_name(realm_name)) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp registered_on_interface?(realm_name, device, interface) do
    group = "devices-with-data-on-interface-#{interface.name}-v#{interface.major_version}"
    key = device.encoded_id

    case KvStore.fetch_value(group, key, :binary, prefix: Realm.keyspace_name(realm_name)) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end
end
