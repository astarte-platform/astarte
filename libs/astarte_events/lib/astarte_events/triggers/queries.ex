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

defmodule Astarte.Events.Triggers.Queries do
  require Logger

  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Realms.SimpleTrigger
  alias Astarte.DataAccess.Repo

  import Ecto.Query

  @type trigger_id() :: Astarte.DataAccess.UUID.t()

  def retrieve_policy_name(realm_name, trigger_id) do
    keyspace_name = Realm.keyspace_name(realm_name)

    trigger_id =
      trigger_id
      |> UUID.binary_to_string!()

    opts = [
      prefix: keyspace_name,
      consistency: Consistency.domain_model(:read),
      error: :policy_not_found
    ]

    KvStore.fetch_value("trigger_to_policy", trigger_id, :binary, opts)
  end

  @spec get_policy_name_map(String.t(), [trigger_id()]) :: %{trigger_id() => String.t()}
  def get_policy_name_map(realm_name, trigger_ids) do
    keyspace_name = Realm.keyspace_name(realm_name)

    opts = [
      prefix: keyspace_name,
      consistency: Consistency.domain_model(:read)
    ]

    trigger_ids
    |> Enum.map(&UUID.binary_to_string!/1)
    |> Enum.chunk_every(99)
    |> Enum.map(fn trigger_id_chunk ->
      KvStore
      |> where([kv], kv.group == "trigger_to_policy" and kv.key in ^trigger_id_chunk)
      |> Repo.all(opts)
    end)
    |> Enum.concat()
    |> Map.new(fn kv_entry ->
      trigger_id = kv_entry.key |> UUID.string_to_binary!()
      policy_name = kv_entry.value
      {trigger_id, policy_name}
    end)
  end

  @spec get_device_groups(String.t(), Astarte.DataAccess.UUID.t()) :: [String.t()]
  def get_device_groups(realm_name, device_id) do
    keyspace_name = Realm.keyspace_name(realm_name)

    opts = [
      prefix: keyspace_name,
      consistency: Consistency.domain_model(:read)
    ]

    Device
    |> select([:groups])
    |> Repo.get(device_id, opts)
    |> case do
      nil -> []
      %{groups: nil} -> []
      %{groups: groups} -> Map.keys(groups)
    end
  end

  @spec query_simple_triggers!(String.t(), Astarte.DataAccess.UUID.t(), integer()) :: [SimpleTrigger.t()]
  def query_simple_triggers!(realm, object_id, object_type_int) do
    keyspace_name = Realm.keyspace_name(realm)

    query =
      SimpleTrigger
      |> where(object_id: ^object_id, object_type: ^object_type_int)
      |> put_query_prefix(keyspace_name)

    Repo.all(query, consistency: Consistency.domain_model(:read))
  end
end
