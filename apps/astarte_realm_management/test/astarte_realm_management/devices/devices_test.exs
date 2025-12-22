#
# This file is part of Astarte.
#
# Copyright 2023 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.DevicesTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use Astarte.Cases.Triggers
  use ExUnitProperties
  use Mimic

  alias Astarte.RealmManagement.Devices
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.RealmManagement.RPC.DataUpdaterPlant.Client, as: DevicesRPC
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.Core.Device, as: DeviceCore
  alias Astarte.RealmManagement.DeviceRemoval.Queries
  alias Astarte.RealmManagement.Devices.Queries, as: DeviceQueries

  import Astarte.Helpers.Triggers

  describe "deletion in progress tests" do
    @describetag :devices
    test "device is inserted in deletion in progress on deletion request", %{
      realm: realm,
      device_id: device_id
    } do
      DevicesRPC
      |> expect(:start_device_deletion_rpc, fn _, _ -> :ok end)

      keyspace = Realm.keyspace_name(realm)
      {:ok, decoded_id} = DeviceCore.decode_device_id(device_id)

      assert :ok = Devices.delete_device(realm, device_id)

      [deletion] = Repo.all(DeletionInProgress, prefix: keyspace)
      _ = Repo.delete!(deletion)

      assert decoded_id == deletion.device_id
      refute DeletionInProgress.all_ack?(deletion)
    end

    property "is not queued for deletion if there are no acks", %{realm: realm} do
      check all(device_id <- Astarte.Core.Generators.Device.id()) do
        DevicesRPC
        |> expect(:start_device_deletion_rpc, fn _, _ -> :ok end)

        keyspace = Realm.keyspace_name(realm)
        device = %Device{device_id: device_id}

        Repo.insert!(device, prefix: keyspace)

        encoded_device_id = DeviceCore.encode_device_id(device_id)
        :ok = Devices.delete_device(realm, encoded_device_id)

        assert [] = Queries.retrieve_devices_to_delete!(realm)

        %DeletionInProgress{
          device_id: device_id,
          dup_end_ack: false,
          vmq_ack: false,
          dup_start_ack: false
        }
        |> Repo.delete!(prefix: keyspace)

        Repo.delete!(device, prefix: keyspace)
      end
    end

    property "is queued for deletion with all acks", %{realm: realm} do
      check all(device <- Astarte.Core.Generators.Device.device(interfaces: [])) do
        keyspace = Realm.keyspace_name(realm)
        device_id = device.device_id
        device = %Device{device_id: device_id}

        Repo.insert!(device, prefix: keyspace)

        %DeletionInProgress{
          device_id: device_id,
          vmq_ack: true,
          dup_end_ack: true,
          dup_start_ack: true
        }
        |> Repo.insert!(prefix: keyspace)

        assert [deletion] = Queries.retrieve_devices_to_delete!(realm)
        _ = Repo.delete!(deletion, prefix: keyspace)

        assert %DeletionInProgress{
                 device_id: ^device_id,
                 vmq_ack: true,
                 dup_end_ack: true,
                 dup_start_ack: true
               } = deletion

        Repo.delete!(device, prefix: keyspace)
      end
    end

    test "generates deletion started triggers", %{realm: realm, device_id: device_id} do
      DevicesRPC
      |> expect(:start_device_deletion_rpc, fn _, _ -> :ok end)

      ref = register_device_deletion_started_trigger(realm, device_id: device_id)
      reset_cache(realm)
      start_device_deletion(realm, device_id)

      assert_receive ^ref
    end

    property "does not delete a non existing device", %{realm: realm} do
      check all(encoded_device_id <- DeviceGenerator.encoded_id()) do
        assert {:error, :device_not_found} = Devices.delete_device(realm, encoded_device_id)
      end
    end
  end

  @tag :regression
  test "device deletion does not overwrite existing entries", %{realm: realm} do
    DevicesRPC
    |> expect(:start_device_deletion_rpc, fn _, _ -> :ok end)

    keyspace = Realm.keyspace_name(realm)
    device_id = Astarte.Core.Generators.Device.id() |> Enum.at(0)
    encoded_id = Astarte.Core.Device.encode_device_id(device_id)

    device =
      %Device{
        device_id: device_id
      }

    entry =
      %DeletionInProgress{
        device_id: device_id,
        dup_end_ack: false,
        dup_start_ack: true,
        vmq_ack: true
      }

    on_exit(fn -> Repo.delete(device, prefix: keyspace) end)
    Repo.insert!(device, prefix: keyspace)

    on_exit(fn -> Repo.delete(entry, prefix: keyspace) end)
    Repo.insert!(entry, prefix: keyspace)

    assert :ok = Devices.delete_device(realm, encoded_id)
    assert {:ok, fetched} = Repo.fetch(DeletionInProgress, device_id, prefix: keyspace)
    assert Map.delete(fetched, :__meta__) == Map.delete(entry, :__meta__)
  end

  @tag :regression
  test "status is cleaned in case of race conditions with device existence check", context do
    Mimic.reject(&DevicesRPC.start_device_deletion_rpc/2)

    %{realm: realm} = context
    keyspace = Realm.keyspace_name(realm)
    device_id = Astarte.Core.Generators.Device.id() |> Enum.at(0)
    encoded_id = Astarte.Core.Device.encode_device_id(device_id)

    DeviceQueries
    |> expect(:device_exists?, fn ^realm, ^device_id -> true end)
    |> expect(:device_exists?, fn ^realm, ^device_id -> false end)

    assert :ok = Devices.delete_device(realm, encoded_id)
    assert {:error, :not_found} = Repo.fetch(DeletionInProgress, device_id, prefix: keyspace)
  end

  defp start_device_deletion(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)
    {:ok, decoded_id} = DeviceCore.decode_device_id(device_id)

    on_exit(fn ->
      %DeletionInProgress{device_id: decoded_id}
      |> Repo.delete(prefix: keyspace)
    end)

    Devices.delete_device(realm_name, device_id)
  end
end
