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

defmodule Astarte.TestSuite.Helpers.Trigger do
  @moduledoc false

  import Astarte.Core.Generators.Triggers.Trigger, only: [trigger: 1]
  import Astarte.DataAccess.Adapters.Triggers.Trigger, only: [from_core_trigger_to_change: 1]
  import Astarte.TestSuite.CaseContext, only: [get!: 3, put!: 5, put_fixture: 3, reduce: 4]

  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm, as: RealmData

  def triggers(%{trigger_number: trigger_number} = context) do
    reduce(context, :realms, context, fn realm_id, _realm, _instance_id, acc ->
      context
      |> policy_name(realm_id)
      |> triggers_for_realm(trigger_number)
      |> Enum.reduce(acc, fn %{name: name} = trigger, inner_acc ->
        put!(inner_acc, :triggers, realm_id <> ":" <> name, trigger, realm_id)
      end)
    end)
  end

  def data(context) do
    results =
      reduce(context, :triggers, [], fn _trigger_id, trigger, realm_id, results ->
        [persist_trigger!(context, trigger, realm_id) | results]
      end)

    put_fixture(context, :trigger_data, %{
      trigger_database_results: results,
      triggers_registered?: true
    })
  end

  defp policy_name(%{policies: policies}, realm_id),
    do: policy_name_for(Map.to_list(policies), realm_id)

  defp policy_name(_context, _realm_id), do: nil

  defp policy_name_for([], _realm_id), do: nil

  defp policy_name_for([{_policy_id, {%{name: policy_name}, realm_id}} | _policies], realm_id),
    do: policy_name

  defp policy_name_for([_policy | policies], realm_id), do: policy_name_for(policies, realm_id)

  defp triggers_for_realm(policy_name, trigger_number),
    do:
      trigger(policy: policy_name)
      |> Stream.uniq_by(& &1.name)
      |> Stream.uniq_by(& &1.trigger_uuid)
      |> Enum.take(trigger_number)

  defp persist_trigger!(context, trigger, realm_id) do
    %{id: realm_name} = get!(context, :realms, realm_id)
    changes = from_core_trigger_to_change(trigger)

    opts = [
      prefix: RealmData.keyspace_name(realm_name),
      consistency: Consistency.domain_model(:write)
    ]

    changes
    |> trigger_entries()
    |> insert_entries!(opts)

    changes
  end

  defp trigger_entries(%{
         trigger: trigger,
         trigger_by_name: trigger_by_name,
         policy_links: links
       }),
       do: [trigger, trigger_by_name | links]

  defp insert_entries!([], _opts), do: :ok

  defp insert_entries!([entry | entries], opts) do
    :ok = KvStore.insert(entry, opts)
    insert_entries!(entries, opts)
  end
end
