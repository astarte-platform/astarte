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

defmodule Astarte.TestSuite.Helpers.Device do
  @moduledoc false

  import Astarte.Core.Generators.Device, only: [device: 1]
  import Astarte.DataAccess.Adapters.Device, only: [from_core_device_to_change: 1]

  import Astarte.TestSuite.CaseContext,
    only: [get!: 3, put!: 5, put_fixture: 3, reduce: 4]

  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Device, as: DeviceData
  alias Astarte.DataAccess.Realms.Name, as: NameData
  alias Astarte.DataAccess.Realms.Realm, as: RealmData
  alias Astarte.DataAccess.Repo

  def devices(%{device_number: device_number} = context) do
    reduce(context, :interfaces, context, fn interface_id, interface, _realm_id, acc ->
      interface
      |> devices_for_interface(device_number)
      |> Enum.reduce(acc, fn %{encoded_id: encoded_id} = device, inner_acc ->
        put!(inner_acc, :devices, encoded_id, device, interface_id)
      end)
    end)
  end

  def data(%{interfaces: interfaces} = context) do
    results =
      reduce(context, :devices, [], fn _device_id, device, interface_id, results ->
        [persist_device!(context, interfaces, device, interface_id) | results]
      end)

    put_fixture(context, :device_data, %{
      device_database_results: results,
      devices_registered?: true
    })
  end

  defp devices_for_interface(interface, device_number),
    do:
      device(interfaces: [interface])
      |> Stream.uniq_by(& &1.device_id)
      |> Enum.take(device_number)

  defp persist_device!(context, interfaces, device, interface_id) do
    {interface, realm_id} = Map.fetch!(interfaces, interface_id)
    %{id: realm_name} = get!(context, :realms, realm_id)
    keyspace = RealmData.keyspace_name(realm_name)

    %{device: device_changes, names: name_changes} =
      device
      |> Map.put(:grouped_devices, [])
      |> Map.put(:interfaces, [interface])
      |> from_core_device_to_change()

    opts = [prefix: keyspace, consistency: Consistency.device_info(:write)]
    device_result = Repo.insert!(struct(DeviceData, device_changes), opts)
    name_results = Enum.map(name_changes, &Repo.insert!(struct(NameData, &1), opts))

    %{device: device_result, names: name_results}
  end
end
