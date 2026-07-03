#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.RealmManagement.DeviceRemoval.SchedulerSyncTest do
  @moduledoc """
  Tests for the device remover scheduler.
  """

  use Astarte.Cases.Data
  use ExUnitProperties
  use Mimic

  alias Astarte.Core.Generators.Device, as: DeviceGenerator

  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  alias Astarte.RealmManagement.DeviceRemoval.Scheduler
  alias Astarte.RealmManagement.Generators.DeletionInProgress, as: DeletionGenerator
  alias Astarte.RealmManagement.RPC.DataUpdaterPlant.Client, as: DevicesRPC

  import Astarte.Helpers.Device

  setup :set_mimic_global

  describe "delete_device/2" do
    setup :seed_device

    test "deletes confirmed devices", context do
      %{realm: realm_name, device_id: device_id} = context
      confirm_device(realm_name, device_id)
      assert {:ok, pid} = Scheduler.delete_device(realm_name, device_id)
      await_task(pid)
      refute Repo.get(Device, device_id, prefix: Realm.keyspace_name(realm_name))
    end

    test "does nothing for unconfirmed devices", context do
      %{realm: realm_name, device_id: device_id} = context
      assert Scheduler.delete_device(realm_name, device_id) == {:error, :device_not_ready}
    end
  end

  describe "reschedule_pending_deletions/0" do
    property "re-sends the RPC only for devices missing at least one ack", %{realm: realm} do
      check all ackd_devices <- DeviceGenerator.id() |> list_of(length: 1..5),
                non_ackd_devices <-
                  DeviceGenerator.id()
                  |> filter(&(&1 not in ackd_devices))
                  |> bind(&DeletionGenerator.deletion_in_progress(device_id: &1))
                  |> filter(&(not DeletionInProgress.all_ack?(&1)))
                  |> list_of(length: 1..5),
                max_runs: 10 do
        ackd_deletions = seed_ackd_deletions(ackd_devices, realm)
        non_ackd_deletions = seed_non_ackd_deletions(non_ackd_devices, realm)
        non_ackd_device_ids = Enum.map(non_ackd_devices, & &1.device_id)

        test_process = self()

        DevicesRPC
        |> expect(:start_device_deletion_rpc, length(non_ackd_device_ids), fn ^realm, device_id ->
          send(test_process, {:rpc_called, device_id})
          :ok
        end)

        assert Scheduler.reschedule_pending_deletions() == :ok

        for device_id <- non_ackd_device_ids do
          assert_receive {:rpc_called, ^device_id}
        end

        for device_id <- ackd_devices do
          refute_receive {:rpc_called, ^device_id}
        end

        (ackd_deletions ++ non_ackd_deletions)
        |> Enum.each(&Repo.delete!(&1, prefix: Realm.keyspace_name(realm)))
      end
    end
  end

  defp await_task(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    after
      5000 -> flunk("task timeout")
    end
  end

  defp seed_device(context) do
    %{realm: realm_name} = context
    keyspace = Realm.keyspace_name(realm_name)
    device = DeviceGenerator.device() |> Enum.at(0)

    on_exit(fn ->
      %Device{device_id: device.device_id}
      |> Repo.delete(prefix: keyspace)
    end)

    insert_device_cleanly(realm_name, device, [], [])

    %{device_id: device.device_id}
  end

  defp confirm_device(realm_name, device_id) do
    %DeletionInProgress{
      device_id: device_id,
      dup_end_ack: true,
      dup_start_ack: true,
      vmq_ack: true
    }
    |> Repo.insert!(prefix: Realm.keyspace_name(realm_name))
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
