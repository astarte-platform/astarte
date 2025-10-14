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

defmodule Astarte.RealmManagement.DeviceRemoval.DeviceRemoverTest do
  @moduledoc """
    Tests for device remover.
  """

  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties

  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.RealmManagement.DeviceRemoval.DeviceRemover
  alias Astarte.DataAccess.Repo

  import Astarte.Helpers.Triggers

  setup %{realm_name: realm_name, decoded_device_id: device_id, groups: groups} do
    insert_deletion_entry(realm_name, device_id, groups)
    :ok
  end

  test "executes device deletion triggers", context do
    %{
      realm_name: realm_name,
      device_id: encoded_id,
      decoded_device_id: device_id
    } = context

    ref = register_device_deletion_finished_trigger(realm_name, device_id: encoded_id)
    reset_cache(realm_name)
    DeviceRemover.run(%{device_id: device_id, realm_name: realm_name})

    assert_receive ^ref
  end

  test "executes device deletion trigger even if device has already been deleted", context do
    %{
      realm_name: realm_name
    } = context

    # This is a device not in the database, which is the same as a device with all data
    # already deleted
    device_id = Astarte.Core.Device.random_device_id()
    groups = string(:alphanumeric, min_length: 5) |> Enum.take(3)

    ref = register_device_deletion_finished_trigger(realm_name, group_name: Enum.random(groups))

    reset_cache(realm_name)
    insert_deletion_entry(realm_name, device_id, groups)
    DeviceRemover.run(%{device_id: device_id, realm_name: realm_name})

    assert_receive ^ref
  end

  defp insert_deletion_entry(realm_name, device_id, groups) do
    keyspace = Realm.keyspace_name(realm_name)

    deletion_in_progress = %DeletionInProgress{
      device_id: device_id,
      dup_end_ack: true,
      dup_start_ack: true,
      vmq_ack: true,
      groups: groups
    }

    on_exit(fn ->
      Repo.delete(deletion_in_progress, prefix: keyspace)
    end)

    Repo.insert(deletion_in_progress, prefix: keyspace)
  end
end
