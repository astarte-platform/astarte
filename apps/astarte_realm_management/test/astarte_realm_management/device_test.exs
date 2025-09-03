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

defmodule Astarte.RealmManagement.DeviceTest do
  @moduledoc """
  Test for the `Device` section of the RealmManagement Engine
  """
  alias Astarte.RealmManagement.Queries
  alias Astarte.RealmManagement.Engine
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Devices.Device

  use Astarte.RealmManagement.DataCase, async: true
  use ExUnitProperties
  use Mimic

  describe "Test device" do
    @describetag :devices
    property "gets put in deletion in progress on deletion request", %{realm: realm} do
      check all(device_id <- Astarte.Core.Generators.Device.id()) do
        keyspace = Realm.keyspace_name(realm)

        %Device{
          device_id: device_id
        }
        |> Repo.insert!(prefix: keyspace)

        encoded_device_id = Astarte.Core.Device.encode_device_id(device_id)
        :ok = Engine.delete_device(realm, encoded_device_id)

        [deletion] = Repo.all(DeletionInProgress, prefix: keyspace)
        _ = Repo.delete!(deletion)

        assert device_id == deletion.device_id
        refute DeletionInProgress.all_ack?(deletion)
      end
    end

    property "is not queued for deletion if there are no acks", %{realm: realm} do
      check all(device_id <- Astarte.Core.Generators.Device.id()) do
        keyspace = Realm.keyspace_name(realm)

        %Device{
          device_id: device_id
        }
        |> Repo.insert!(prefix: keyspace)

        encoded_device_id = Astarte.Core.Device.encode_device_id(device_id)
        :ok = Engine.delete_device(realm, encoded_device_id)

        assert [] = Queries.retrieve_devices_to_delete!(realm)

        %DeletionInProgress{
          device_id: device_id,
          dup_end_ack: false,
          vmq_ack: false,
          dup_start_ack: false
        }
        |> Repo.delete!(prefix: keyspace)
      end
    end

    property "is queued for deletion with all acks", %{realm: realm} do
      check all(device <- Astarte.Core.Generators.Device.device(interfaces: [])) do
        keyspace = Realm.keyspace_name(realm)

        %Device{
          device_id: device.device_id
        }
        |> Repo.insert!(prefix: keyspace)

        %DeletionInProgress{
          device_id: device.device_id,
          vmq_ack: true,
          dup_end_ack: true,
          dup_start_ack: true
        }
        |> Repo.insert!(prefix: keyspace)

        assert [deletion] = Queries.retrieve_devices_to_delete!(realm)
        _ = Repo.delete!(deletion)

        device_id = device.device_id

        assert %DeletionInProgress{
                 device_id: ^device_id,
                 vmq_ack: true,
                 dup_end_ack: true,
                 dup_start_ack: true
               } = deletion
      end
    end

    property "does not delete a non existing device", %{realm: realm} do
      check all(encoded_device_id <- Astarte.Core.Generators.Device.encoded_id()) do
        assert {:error, :device_not_found} = Engine.delete_device(realm, encoded_device_id)
      end
    end
  end

  @tag :regression
  test "device deletion does not overwrite existing entries", %{realm: realm} do
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

    assert :ok = Engine.delete_device(realm, encoded_id)
    assert {:ok, fetched} = Repo.fetch(DeletionInProgress, device_id, prefix: keyspace)
    assert Map.delete(fetched, :__meta__) == Map.delete(entry, :__meta__)
  end

  @tag :regression
  test "status is cleaned in case of race conditions with device existence check", context do
    %{realm: realm} = context
    keyspace = Realm.keyspace_name(realm)
    device_id = Astarte.Core.Generators.Device.id() |> Enum.at(0)
    encoded_id = Astarte.Core.Device.encode_device_id(device_id)

    Queries
    |> expect(:device_exists?, fn ^realm, ^device_id -> true end)
    |> expect(:device_exists?, fn ^realm, ^device_id -> false end)

    assert :ok = Engine.delete_device(realm, encoded_id)
    assert {:error, :not_found} = Repo.fetch(DeletionInProgress, device_id, prefix: keyspace)
  end
end
