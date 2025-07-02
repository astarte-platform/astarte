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

defmodule Astarte.RealmManagement.DeviceRemoval.SchedulerTest do
  @moduledoc """
  Tests for the device remover scheduler.
  """
  alias Astarte.RealmManagement.API.DeviceRemoval.Queries
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.RealmManagement.API.Generators.DeletionInProgress, as: DeletionGenerator

  use Astarte.Cases.Data, async: true
  use ExUnitProperties

  # We only test this as is the only important logic happening inside of the
  # Scheduler. The rest of the logic consists in calling itself after a
  # pre-determined timeout and running a task.
  property "Test device removal happens only when all ACKs are available", %{realm: realm} do
    check all(
            ackd_devices <- Astarte.Core.Generators.Device.id() |> list_of(length: 1..10),
            non_ackd <-
              Astarte.Core.Generators.Device.id()
              |> StreamData.filter(fn id -> id not in ackd_devices end)
              |> DeletionGenerator.deletion_in_progress()
              |> StreamData.filter(fn deletion -> not DeletionInProgress.all_ack?(deletion) end)
              |> list_of(length: 1..10)
          ) do
      ackd_deletions = seed_ackd_deletions(ackd_devices, realm)
      non_ackd_deletions = seed_non_ackd_deletions(non_ackd, realm)

      devices_to_delete =
        Queries.retrieve_devices_to_delete!(realm)
        |> Enum.map(fn deletion -> deletion.device_id end)
        |> Enum.sort()

      # This should be enough, if some non-ackd device is in the
      # `devices_to_delete` list there is a bug, i.e., the two sorted lists
      # should be identical
      assert Enum.sort(ackd_devices) == devices_to_delete

      (ackd_deletions ++ non_ackd_deletions)
      |> Enum.each(&Repo.delete!(&1, prefix: Realm.keyspace_name(realm)))
    end
  end

  defp seed_ackd_deletions(devices, realm) do
    keyspace = Realm.keyspace_name(realm)

    devices
    |> Enum.map(fn device_id ->
      %DeletionInProgress{
        device_id: device_id,
        dup_end_ack: true,
        dup_start_ack: true,
        vmq_ack: true
      }
      |> Repo.insert!(prefix: keyspace)
    end)
  end

  defp seed_non_ackd_deletions(deletions, realm) do
    keyspace = Realm.keyspace_name(realm)
    Enum.map(deletions, &Repo.insert!(&1, prefix: keyspace))
  end
end
