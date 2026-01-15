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

defmodule Astarte.RealmManagement.Triggers.Policies.Queries do
  require Logger
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  import Ecto.Query

  @doc """
  Fetches the list of trigger policy names for a given realm.

  ## Parameters
    - `realm_name` (`String.t`): The name of the realm from which to fetch the trigger policies.

  ## Returns
    - `{:ok, policies_list}`: A tuple containing `:ok` and a list of policies.
    - `{:error, reason}`: If there was an error fetching the policies.

  ## Example

      iex> get_trigger_policies_list("my_realm")
      {:ok, ["policy_1", "policy_2", "policy_3"]}
  """
  def get_trigger_policies_list(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from(store in KvStore,
        select: store.key,
        where: [group: "trigger_policy"]
      )

    opts = [
      prefix: keyspace,
      consistency: Consistency.domain_model(:read)
    ]

    Repo.fetch_all(query, opts)
  end

  def install_trigger_policy(realm_name, policy_name, policy_proto) do
    keyspace = Realm.keyspace_name(realm_name)

    params = %{
      group: "trigger_policy",
      key: policy_name,
      value: policy_proto
    }

    opts = [
      prefix: keyspace,
      consistency: Consistency.domain_model(:write)
    ]

    KvStore.insert(params, opts)
  end

  def delete_trigger_policy(realm_name, policy_name) do
    _ =
      Logger.info("Delete trigger policy.",
        policy_name: policy_name,
        tag: "db_delete_trigger_policy"
      )

    keyspace = Realm.keyspace_name(realm_name)

    delete_policy_query =
      from(KvStore,
        prefix: ^keyspace,
        where: [group: "trigger_policy", key: ^policy_name]
      )

    group_name = "triggers-with-policy-#{policy_name}"

    delete_triggers_with_policy_group_query =
      from(KvStore,
        prefix: ^keyspace,
        where: [group: ^group_name]
      )

    delete_trigger_to_policy_query =
      from(KvStore,
        prefix: ^keyspace,
        where: [group: "trigger_to_policy"]
      )

    consistency = Consistency.domain_model(:write)

    _ = Repo.delete_all(delete_policy_query, consistency: consistency)
    _ = Repo.delete_all(delete_triggers_with_policy_group_query, consistency: consistency)
    _ = Repo.delete_all(delete_trigger_to_policy_query, consistency: consistency)

    :ok
  end
end
