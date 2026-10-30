#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.TestSuite.Helpers.Group do
  @moduledoc false

  import Ecto.Query

  import Astarte.Core.Generators.Group, only: [group: 1]
  import Astarte.DataAccess.Adapters.Group, only: [from_core_group_to_change: 1]

  import Astarte.TestSuite.CaseContext,
    only: [get!: 3, put!: 5, put_fixture: 3, reduce: 4]

  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Device, as: DeviceData
  alias Astarte.DataAccess.Groups.Group, as: GroupData
  alias Astarte.DataAccess.Groups.GroupedDevice
  alias Astarte.DataAccess.Realms.Realm, as: RealmData
  alias Astarte.DataAccess.Repo

  def group_name(%{group_number: group_number}), do: "group-#{group_number}"

  def groups(%{group_name: group_name} = context) do
    reduce(context, :devices, context, fn device_id, device, _interface_id, acc ->
      group = group_for_device(device, group_name)
      put!(acc, :groups, device_id <> ":" <> group_name, group, device_id)
    end)
  end

  def data(%{devices: devices, interfaces: interfaces} = context) do
    results =
      reduce(context, :groups, [], fn _group_id, group, device_id, results ->
        [persist_group!(context, devices, interfaces, group, device_id) | results]
      end)

    put_fixture(context, :group_data, %{
      group_database_results: results,
      groups_ready?: true
    })
  end

  defp group_for_device(%{device_id: device_id}, group_name),
    do: group(name: group_name, device_ids: [device_id]) |> Enum.at(0)

  defp persist_group!(
         context,
         devices,
         interfaces,
         %{device_ids: device_ids} = group,
         device_id
       ) do
    {_device, interface_id} = Map.fetch!(devices, device_id)
    {_interface, realm_id} = Map.fetch!(interfaces, interface_id)
    %{id: realm_name} = get!(context, :realms, realm_id)

    source = Map.put(group, :insertion_uuids, insertion_uuids(device_ids))

    %{devices: device_changes, group: group_changes, grouped_devices: grouped_devices} =
      from_core_group_to_change(source)

    %GroupData{}
    |> GroupData.changeset(group_changes)
    |> Ecto.Changeset.apply_action!(:insert)

    keyspace = RealmData.keyspace_name(realm_name)
    opts = [prefix: keyspace, consistency: Consistency.device_info(:write)]

    device_results = Enum.map(device_changes, &update_device(&1, keyspace))
    grouped_device_results = Enum.map(grouped_devices, &insert_grouped_device(&1, opts))

    %{devices: device_results, grouped_devices: grouped_device_results}
  end

  defp update_device(%{device_id: device_id, groups: groups}, keyspace) do
    from(DeviceData, prefix: ^keyspace, where: [device_id: ^device_id])
    |> update([device], set: [groups: fragment("groups + ?", ^groups)])
    |> Repo.update_all([], consistency: Consistency.device_info(:write))
  end

  defp insert_grouped_device(grouped_device, opts),
    do: Repo.insert!(struct(GroupedDevice, grouped_device), opts)

  defp insertion_uuids(device_ids),
    do: Enum.map(device_ids, fn _device_id -> insertion_uuid() end)

  defp insertion_uuid do
    <<clock_sequence::14, _::2>> = :crypto.strong_rand_bytes(2)
    UUID.uuid1(<<clock_sequence::14>>, :crypto.strong_rand_bytes(6), :raw)
  end
end
