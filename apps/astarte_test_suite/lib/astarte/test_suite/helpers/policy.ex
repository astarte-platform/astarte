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

defmodule Astarte.TestSuite.Helpers.Policy do
  @moduledoc false

  import Astarte.Core.Generators.Triggers.Policy, only: [policy: 0]

  import Astarte.DataAccess.Adapters.Triggers.Policy,
    only: [from_core_triggers_policy_to_change: 1]

  import Astarte.TestSuite.CaseContext, only: [get!: 3, put!: 5, put_fixture: 3, reduce: 4]

  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm, as: RealmData

  def policies(%{policy_number: policy_number} = context) do
    reduce(context, :realms, context, fn realm_id, _realm, _instance_id, acc ->
      policy()
      |> Stream.uniq_by(& &1.name)
      |> Enum.take(policy_number)
      |> Enum.reduce(acc, fn %{name: name} = policy, inner_acc ->
        put!(inner_acc, :policies, realm_id <> ":" <> name, policy, realm_id)
      end)
    end)
  end

  def data(context) do
    results =
      reduce(context, :policies, [], fn _policy_id, policy, realm_id, results ->
        [persist_policy!(context, policy, realm_id) | results]
      end)

    put_fixture(context, :policy_data, %{
      policies_registered?: true,
      policy_database_results: results
    })
  end

  defp persist_policy!(context, policy, realm_id) do
    %{id: realm_name} = get!(context, :realms, realm_id)
    changes = from_core_triggers_policy_to_change(policy)

    :ok =
      KvStore.insert(changes,
        prefix: RealmData.keyspace_name(realm_name),
        consistency: Consistency.domain_model(:write)
      )

    changes
  end
end
