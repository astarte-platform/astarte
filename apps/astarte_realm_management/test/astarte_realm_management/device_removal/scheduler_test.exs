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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.RealmManagement.DeviceRemoval.SchedulerTest do
  @moduledoc """
  Tests for the device remover scheduler.
  """
  use ExUnitProperties

  use Astarte.Cases.Data, async: true

  use Mimic

  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.Core.Generators.Device, as: DeviceGenerator

  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  alias Astarte.RealmManagement.DeviceRemoval.DeviceRemover
  alias Astarte.RealmManagement.DeviceRemoval.Queries
  alias Astarte.RealmManagement.DeviceRemoval.Scheduler
  alias Astarte.RealmManagement.DeviceRemoverSupervisor

  alias Astarte.RealmManagement.Generators.DeletionInProgress, as: DeletionGenerator

  # We only test this as is the only important logic happening inside of the
  # Scheduler. The rest of the logic consists in calling itself after a
  # pre-determined timeout and running a task.
  property "Test device removal happens only when all ACKs are available", %{realm: realm} do
    check all ackd_devices <- DeviceGenerator.id() |> list_of(length: 1..10),
              non_ackd_devices <-
                DeviceGenerator.id()
                |> filter(&(&1 not in ackd_devices))
                |> bind(&DeletionGenerator.deletion_in_progress(device_id: &1))
                |> filter(&(not DeletionInProgress.all_ack?(&1)))
                |> list_of(length: 1..10),
              max_runs: 25 do
      ackd_deletions = seed_ackd_deletions(ackd_devices, realm)
      non_ackd_deletions = seed_non_ackd_deletions(non_ackd_devices, realm)

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

  defp expect_removal(realm_name, device_ids) do
    test_process = self()

    Realm.keyspace_name(realm_name)

    for _ <- device_ids do
      Task.Supervisor
      |> expect(:start_child, fn DeviceRemoverSupervisor,
                                 DeviceRemover,
                                 :run,
                                 [%{realm_name: ^realm_name, device_id: device_id}],
                                 _opts ->
        send(test_process, {:received_device, device_id})
        {:ok, test_process}
      end)
    end
  end

  defp assert_removal(realm_name, device_ids) do
    for device_id <- device_ids do
      assert_receive {:received_device, ^device_id}
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
