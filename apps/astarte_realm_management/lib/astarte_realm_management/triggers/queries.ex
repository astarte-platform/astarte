#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.Triggers.Queries do
  alias Astarte.Core.AstarteReference
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.Trigger
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Realms.SimpleTrigger
  alias Astarte.DataAccess.Repo

  import Ecto.Query

  require Logger

  def retrieve_trigger_uuid(realm_name, trigger_name) do
    keyspace = Realm.keyspace_name(realm_name)

    opts = [
      prefix: keyspace,
      consistency: Consistency.domain_model(:read),
      error: :trigger_not_found
    ]

    with {:ok, uuid} <-
           KvStore.fetch_value("triggers-by-name", trigger_name, :binary, opts) do
      {:ok, UUID.binary_to_string!(uuid)}
    end
  end

  def retrieve_trigger(realm_name, trigger_name) do
    with {:ok, trigger_uuid} <- retrieve_trigger_uuid(realm_name, trigger_name) do
      keyspace = Realm.keyspace_name(realm_name)

      trigger_uuid = to_string(trigger_uuid)

      query =
        from store in KvStore,
          select: store.value,
          where: [group: "triggers", key: ^trigger_uuid]

      opts = [
        prefix: keyspace,
        consistency: Consistency.domain_model(:read),
        error: :trigger_not_found
      ]

      with {:ok, result} <- Repo.fetch_one(query, opts) do
        {:ok, Trigger.decode(result)}
      end
    end
  end

  # TODO: simple_trigger_uuid is required due how we made the compound key
  # should we move simple_trigger_uuid to the first part of the key?
  def retrieve_tagged_simple_trigger(realm_name, parent_trigger_uuid, simple_trigger_uuid) do
    keyspace = Realm.keyspace_name(realm_name)

    with %{object_uuid: object_id, object_type: object_type} <-
           retrieve_simple_trigger_astarte_ref(realm_name, simple_trigger_uuid) do
      query =
        from trigger in SimpleTrigger,
          select: trigger.trigger_data,
          where: [
            object_id: ^object_id,
            object_type: ^object_type,
            parent_trigger_id: ^parent_trigger_uuid,
            simple_trigger_id: ^simple_trigger_uuid
          ]

      opts = [
        prefix: keyspace,
        consistency: Consistency.domain_model(:read),
        error: :simple_trigger_not_found
      ]

      with {:ok, trigger_data} <- Repo.fetch_one(query, opts) do
        {
          :ok,
          %TaggedSimpleTrigger{
            object_id: object_id,
            object_type: object_type,
            simple_trigger_container: SimpleTriggerContainer.decode(trigger_data)
          }
        }
      end
    end
  end

  defp retrieve_simple_trigger_astarte_ref(realm_name, simple_trigger_uuid) do
    keyspace = Realm.keyspace_name(realm_name)

    simple_trigger_uuid = :uuid.uuid_to_string(simple_trigger_uuid, :binary_standard)

    query =
      from store in KvStore,
        select: store.value,
        where: [group: "simple-triggers-by-uuid", key: ^simple_trigger_uuid]

    opts = [
      prefix: keyspace,
      consistency: Consistency.domain_model(:read),
      error: :trigger_not_found
    ]

    with {:ok, result} <- Repo.fetch_one(query, opts) do
      AstarteReference.decode(result)
    end
  end

  def install_trigger(realm_name, trigger) do
    keyspace = Realm.keyspace_name(realm_name)

    insert_by_name = %{
      group: "triggers-by-name",
      key: trigger.name,
      value: trigger.trigger_uuid,
      value_type: :uuid
    }

    uuid_string =
      trigger.trigger_uuid
      |> :uuid.uuid_to_string()
      |> to_string()

    insert = %{
      group: "triggers",
      key: uuid_string,
      value: Trigger.encode(trigger)
    }

    consistency = Consistency.domain_model(:write)

    with :ok <- KvStore.insert(insert_by_name, prefix: keyspace, consistency: consistency),
         :ok <- KvStore.insert(insert, prefix: keyspace, consistency: consistency) do
      :ok
    else
      not_ok ->
        _ = Logger.warning("Database error: #{inspect(not_ok)}.", tag: "db_error")
        {:error, :cannot_install_trigger}
    end
  end

  def install_simple_trigger(
        realm_name,
        object_id,
        object_type,
        parent_trigger_id,
        simple_trigger_id,
        simple_trigger,
        trigger_target
      ) do
    keyspace = Realm.keyspace_name(realm_name)

    simple_trigger = %SimpleTrigger{
      object_id: object_id,
      object_type: object_type,
      parent_trigger_id: parent_trigger_id,
      simple_trigger_id: simple_trigger_id,
      trigger_data: SimpleTriggerContainer.encode(simple_trigger),
      trigger_target: TriggerTargetContainer.encode(trigger_target)
    }

    astarte_ref =
      %AstarteReference{
        object_type: object_type,
        object_uuid: object_id
      }
      |> AstarteReference.encode()

    simple_trigger_id =
      simple_trigger_id
      |> :uuid.uuid_to_string()
      |> to_string()

    kv_insert =
      %{
        group: "simple-triggers-by-uuid",
        key: simple_trigger_id,
        value: astarte_ref
      }

    opts = [prefix: keyspace, consistency: Consistency.domain_model(:write)]

    with {:ok, _} <- Repo.insert(simple_trigger, opts),
         :ok <- KvStore.insert(kv_insert, opts) do
      :ok
    end
  end

  def install_trigger_policy_link(_realm_name, _trigger_uuid, nil) do
    :ok
  end

  def install_trigger_policy_link(realm_name, trigger_uuid, trigger_policy) do
    keyspace = Realm.keyspace_name(realm_name)

    trigger_uuid =
      trigger_uuid
      |> :uuid.uuid_to_string()
      |> to_string()

    triggers_with_policy =
      %{
        group: "triggers-with-policy-#{trigger_policy}",
        key: trigger_uuid,
        value: trigger_uuid,
        value_type: :uuid
      }

    trigger_to_policy =
      %{
        group: "trigger_to_policy",
        key: trigger_uuid,
        value: trigger_policy
      }

    opts = [prefix: keyspace, consistency: Consistency.domain_model(:write)]

    with :ok <- KvStore.insert(triggers_with_policy, opts),
         :ok <- KvStore.insert(trigger_to_policy, opts) do
      :ok
    end
  end

  def trigger_policy_exists?(realm_name, policy_name) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from store in KvStore,
        where: [group: "trigger_policy", key: ^policy_name]

    opts = [
      prefix: keyspace,
      consistency: Consistency.domain_model(:read)
    ]

    {:ok, some?} = Repo.some?(query, opts)

    some?
  end

  def policy_has_triggers?(realm_name, policy_name) do
    keyspace = Realm.keyspace_name(realm_name)
    group_name = "triggers-with-policy-#{policy_name}"

    query =
      from store in KvStore,
        select: store.key,
        where: [group: ^group_name],
        limit: 1

    opts = [
      prefix: keyspace,
      consistency: Consistency.domain_model(:read)
    ]

    {:ok, some?} = Repo.some?(query, opts)

    some?
  end

  def delete_trigger(realm_name, trigger_name) do
    with {:ok, trigger_uuid} <- retrieve_trigger_uuid(realm_name, trigger_name) do
      keyspace = Realm.keyspace_name(realm_name)

      trigger_by_name_query =
        KvStore
        |> where(group: "triggers-by-name", key: ^trigger_name)
        |> put_query_prefix(keyspace)

      triggers_query =
        KvStore
        |> where(group: "triggers", key: ^trigger_uuid)
        |> put_query_prefix(keyspace)

      consistency = Consistency.domain_model(:write)

      _ = Repo.delete_all(trigger_by_name_query, consistency: consistency)
      _ = Repo.delete_all(triggers_query, consistency: consistency)

      :ok
    end
  end

  def delete_simple_trigger(realm_name, parent_trigger_uuid, simple_trigger_uuid) do
    with %{object_uuid: object_id, object_type: object_type} <-
           retrieve_simple_trigger_astarte_ref(realm_name, simple_trigger_uuid) do
      keyspace = Realm.keyspace_name(realm_name)

      delete_simple_trigger_query =
        from SimpleTrigger,
          prefix: ^keyspace,
          where: [
            object_id: ^object_id,
            object_type: ^object_type,
            parent_trigger_id: ^parent_trigger_uuid,
            simple_trigger_id: ^simple_trigger_uuid
          ]

      simple_trigger_uuid =
        simple_trigger_uuid
        |> :uuid.uuid_to_string()
        |> to_string()

      delete_astarte_ref_query =
        from KvStore,
          prefix: ^keyspace,
          where: [group: "simple-triggers-by-uuid", key: ^simple_trigger_uuid]

      consistency = Consistency.domain_model(:write)

      _ = Repo.delete_all(delete_astarte_ref_query, consistency: consistency)
      _ = Repo.delete_all(delete_simple_trigger_query, consistency: consistency)

      :ok
    end
  end

  def delete_trigger_policy_link(_realm_name, _trigger_uuid, nil) do
    :ok
  end

  def delete_trigger_policy_link(realm_name, trigger_uuid, trigger_policy) do
    keyspace = Realm.keyspace_name(realm_name)
    policy_group = "triggers-with-policy-#{trigger_policy}"
    trigger_uuid = UUID.binary_to_string!(trigger_uuid)

    triggers_with_policy =
      from KvStore,
        prefix: ^keyspace,
        where: [group: ^policy_group, key: ^trigger_uuid]

    trigger_to_policy =
      from KvStore,
        prefix: ^keyspace,
        where: [group: "trigger_to_policy", key: ^trigger_uuid]

    consistency = Consistency.domain_model(:write)

    _ = Repo.delete_all(triggers_with_policy, consistency: consistency)
    _ = Repo.delete_all(trigger_to_policy, consistency: consistency)

    :ok
  end

  def get_triggers_list(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from store in KvStore,
        select: store.key,
        where: [group: "triggers-by-name"]

    opts = [prefix: keyspace, consistency: Consistency.domain_model(:read)]

    Repo.fetch_all(query, opts)
  end

  def fetch_trigger_policy(realm_name, policy_name) do
    keyspace = Realm.keyspace_name(realm_name)

    KvStore.fetch_value("trigger_policy", policy_name, :binary,
      prefix: keyspace,
      consistency: Consistency.domain_model(:read),
      error: :trigger_policy_not_found
    )
  end
end
