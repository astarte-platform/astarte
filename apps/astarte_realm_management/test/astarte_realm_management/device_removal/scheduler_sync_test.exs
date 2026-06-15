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
end
