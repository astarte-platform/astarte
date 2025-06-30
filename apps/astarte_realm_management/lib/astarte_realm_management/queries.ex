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

defmodule Astarte.RealmManagement.Queries do
  require Logger
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Devices.Device, as: RealmsDevice
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.DataAccess.Realms.IndividualProperty
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Realms.SimpleTrigger
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.KvStore
  alias Astarte.Core.AstarteReference
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Interface, as: InterfaceDocument
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Interface.Aggregation
  alias Astarte.Core.Interface.Ownership
  alias Astarte.Core.Interface.Type, as: InterfaceType
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.DatabaseRetentionPolicy
  alias Astarte.Core.Mapping.Reliability
  alias Astarte.Core.Mapping.Retention
  alias Astarte.Core.Mapping.ValueType
  alias Astarte.Core.StorageType
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.Core.Triggers.Trigger
  alias Astarte.DataAccess.Consistency
  alias Astarte.RealmManagement.Migrations.CreateDatastreamIndividualMultiInterface

  import Ecto.Query

  defp create_one_object_columns_for_mappings(mappings) do
    for %Mapping{endpoint: endpoint, value_type: value_type} <- mappings do
      column_name = CQLUtils.endpoint_to_db_column_name(endpoint)
      cql_type = CQLUtils.mapping_value_type_to_db_type(value_type)
      "#{column_name} #{cql_type}"
    end
    |> Enum.join(~s(,\n))
  end

  defp create_interface_table(
         _keyspace,
         :individual,
         :multi,
         %InterfaceDescriptor{type: :properties},
         _mappings
       ) do
    {:multi_interface_individual_properties_dbtable, "individual_properties"}
  end

  defp create_interface_table(
         keyspace,
         :individual,
         :multi,
         %InterfaceDescriptor{type: :datastream},
         _mappings
       ) do
    _ = Logger.info("Creating new interface table.", tag: "create_interface_table")

    CSystem.run_with_schema_agreement(fn ->
      _ =
        Ecto.Migrator.run(Repo, [{0, CreateDatastreamIndividualMultiInterface}], :up,
          prefix: keyspace,
          all: true
        )
    end)

    {:multi_interface_individual_datastream_dbtable, "individual_datastreams"}
  end

  defp create_interface_table(keyspace, :object, :one, interface_descriptor, mappings) do
    table_name =
      CQLUtils.interface_name_to_table_name(
        interface_descriptor.name,
        interface_descriptor.major_version
      )

    columns = create_one_object_columns_for_mappings(mappings)

    [%Mapping{explicit_timestamp: explicit_timestamp} | _tail] = mappings

    {value_timestamp, key_timestamp} =
      if explicit_timestamp,
        do: {"value_timestamp timestamp,", "value_timestamp,"},
        else: {"", ""}

    create_interface_table_with_object_aggregation = """
      CREATE TABLE #{keyspace}.#{table_name} (
        device_id uuid,
        path varchar,

        #{value_timestamp},
        reception_timestamp timestamp,
        reception_timestamp_submillis smallint,
        #{columns},

        PRIMARY KEY((device_id, path), #{key_timestamp} reception_timestamp, reception_timestamp_submillis)
      )
    """

    _ = Logger.info("Creating new interface table.", tag: "create_interface_table")

    CSystem.run_with_schema_agreement(fn ->
      _ = Repo.query(create_interface_table_with_object_aggregation)
    end)

    {:one_object_datastream_dbtable, table_name}
  end

  def install_new_interface(realm_name, interface_document, automaton) do
    keyspace = Realm.keyspace_name(realm_name)

    table_type =
      if interface_document.aggregation == :individual,
        do: :multi,
        else: :one

    {storage_type, table_name} =
      create_interface_table(
        keyspace,
        interface_document.aggregation,
        table_type,
        InterfaceDescriptor.from_interface(interface_document),
        interface_document.mappings
      )

    {transitions, accepting_states_no_ids} = automaton

    transitions_bin = :erlang.term_to_binary(transitions)

    accepting_states_bin =
      accepting_states_no_ids
      |> replace_automaton_acceptings_with_ids(
        interface_document.name,
        interface_document.major_version
      )
      |> :erlang.term_to_binary()

    # Here order matters, must be the same as the `?` in `insert_interface_statement`
    params =
      [
        interface_document.name,
        interface_document.major_version,
        interface_document.minor_version,
        interface_document.interface_id,
        StorageType.to_int(storage_type),
        table_name,
        InterfaceType.to_int(interface_document.type),
        Ownership.to_int(interface_document.ownership),
        Aggregation.to_int(interface_document.aggregation),
        transitions_bin,
        accepting_states_bin,
        interface_document.description,
        interface_document.doc
      ]

    interface_table = Interface.__schema__(:source)

    insert_interface_statement = """
      INSERT INTO #{keyspace}.#{interface_table}
        (name, major_version, minor_version, interface_id, storage_type, storage, type, ownership, aggregation, automaton_transitions, automaton_accepting_states, description, doc)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """

    interface_query = {insert_interface_statement, params}

    endpoints_queries =
      for mapping <- interface_document.mappings do
        insert_mapping_query(
          keyspace,
          interface_document.interface_id,
          interface_document.name,
          interface_document.major_version,
          interface_document.minor_version,
          interface_document.type,
          mapping
        )
      end

    consistency = Consistency.domain_model(:write)

    Exandra.execute_batch(
      Repo,
      %Exandra.Batch{
        queries: [interface_query | endpoints_queries]
      },
      consistency: consistency
    )
  end

  defp insert_mapping_query(
         keyspace,
         interface_id,
         interface_name,
         major,
         minor,
         interface_type,
         mapping
       ) do
    table_name = Endpoint.__schema__(:source)

    insert_mapping_statement = """
    INSERT INTO #{keyspace}.#{table_name}
    (
      interface_id, endpoint_id, interface_name, interface_major_version, interface_minor_version,
      interface_type, endpoint, value_type, reliability, retention, database_retention_policy,
      database_retention_ttl, expiry, allow_unset, explicit_timestamp, description, doc
    )
    VALUES (
      ?, ?, ?, ?, ?,
      ?, ?, ?, ?, ?, ?,
      ?, ?, ?, ?, ?, ?
    )
    """

    params = [
      interface_id,
      mapping.endpoint_id,
      interface_name,
      major,
      minor,
      InterfaceType.to_int(interface_type),
      mapping.endpoint,
      ValueType.to_int(mapping.value_type),
      Reliability.to_int(mapping.reliability),
      Retention.to_int(mapping.retention),
      DatabaseRetentionPolicy.to_int(mapping.database_retention_policy),
      mapping.database_retention_ttl,
      mapping.expiry,
      mapping.allow_unset,
      mapping.explicit_timestamp,
      mapping.description,
      mapping.doc
    ]

    {insert_mapping_statement, params}
  end

  # TODO: this was needed when Cassandra used to generate endpoint IDs
  # it might be a good idea to drop this and generate those IDs in A.C.Mapping.EndpointsAutomaton
  defp replace_automaton_acceptings_with_ids(accepting_states, interface_name, major) do
    Enum.reduce(accepting_states, %{}, fn state, new_states ->
      {state_index, endpoint} = state

      Map.put(new_states, state_index, CQLUtils.endpoint_id(interface_name, major, endpoint))
    end)
  end

  def delete_interface(realm_name, interface_name, interface_major_version) do
    _ =
      Logger.info("Delete interface.",
        interface: interface_name,
        interface_major: interface_major_version,
        tag: "db_delete_interface"
      )

    keyspace = Realm.keyspace_name(realm_name)

    interface_id = CQLUtils.interface_id(interface_name, interface_major_version)

    endpoint_query =
      from Endpoint,
        prefix: ^keyspace,
        where: [interface_id: ^interface_id]

    interface_query =
      from Interface,
        prefix: ^keyspace,
        where: [name: ^interface_name, major_version: ^interface_major_version]

    queries = [
      Repo.to_sql(:delete_all, endpoint_query),
      Repo.to_sql(:delete_all, interface_query)
    ]

    consistency = Consistency.domain_model(:write)

    Exandra.execute_batch(
      Repo,
      %Exandra.Batch{
        queries: queries
      },
      consistency: consistency
    )
  end

  def delete_devices_with_data_on_interface(realm_name, interface_name) do
    keyspace = Realm.keyspace_name(realm_name)
    group_name = "devices-with-data-on-interface-#{interface_name}-v0"

    query = from KvStore, where: [group: ^group_name]

    consistency = Consistency.domain_model(:write)

    _ = Repo.delete_all(query, prefix: keyspace, consistency: consistency)

    :ok
  end

  def is_interface_major_available?(realm_name, interface_name, interface_major) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from i in Interface,
        where: i.name == ^interface_name,
        where: i.major_version == ^interface_major

    consistency = Consistency.domain_model(:read)

    Repo.some?(query, prefix: keyspace, consistency: consistency)
  end

  defp normalize_interface_name(interface_name) do
    String.replace(interface_name, "-", "")
    |> String.downcase()
  end

  def check_interface_name_collision(realm_name, interface_name) do
    normalized_interface = normalize_interface_name(interface_name)
    keyspace = Realm.keyspace_name(realm_name)

    all_names_query =
      from i in Interface,
        distinct: true,
        select: i.name

    consistency = Consistency.domain_model(:read)

    with {:ok, names} <-
           Repo.fetch_all(all_names_query, prefix: keyspace, consistency: consistency) do
      Enum.reduce_while(names, :ok, fn name, _acc ->
        if normalize_interface_name(name) == normalized_interface do
          if name == interface_name do
            # If there is already an interface with the same name, we know it's possible to install it.
            # Version conflicts will be checked in another function.
            {:halt, :ok}
          else
            {:halt, {:error, :interface_name_collision}}
          end
        else
          {:cont, :ok}
        end
      end)
    end
  end

  def fetch_interface(realm_name, interface_name, interface_major) do
    keyspace = Realm.keyspace_name(realm_name)

    consistency = Consistency.domain_model(:read)

    with {:ok, interface} <-
           Repo.fetch_by(
             Interface,
             [name: interface_name, major_version: interface_major],
             prefix: keyspace,
             consistency: consistency,
             error: :interface_not_found
           ) do
      endpoints_query = from(Endpoint, where: [interface_id: ^interface.interface_id])

      with {:ok, endpoints} <-
             Repo.fetch_all(endpoints_query, prefix: keyspace, consistency: consistency) do
        mappings =
          Enum.map(endpoints, fn endpoint ->
            %Mapping{}
            |> Mapping.changeset(Map.from_struct(endpoint),
              interface_name: interface.name,
              interface_id: interface.interface_id,
              interface_major: interface.major_version,
              interface_type: interface.type
            )
            |> Ecto.Changeset.apply_changes()
            |> Map.from_struct()
            |> Map.put(:type, endpoint.value_type)
          end)

        interface =
          interface
          |> Map.from_struct()
          |> Map.put(:mappings, mappings)
          |> Map.put(:version_major, interface.major_version)
          |> Map.put(:version_minor, interface.minor_version)
          |> Map.put(:interface_name, interface.name)

        interface_document =
          %InterfaceDocument{}
          |> InterfaceDocument.changeset(interface)
          |> Ecto.Changeset.apply_changes()

        {:ok, interface_document}
      end
    end
  end

  def get_interfaces_list(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from i in Interface,
        distinct: true,
        select: i.name

    consistency = Consistency.domain_model(:read)

    Repo.fetch_all(query, prefix: keyspace, consistency: consistency)
  end

  def get_jwt_public_key_pem(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    consistency = Consistency.domain_model(:read)

    KvStore.fetch_value("auth", "jwt_public_key_pem", :string,
      prefix: keyspace,
      consistency: consistency,
      error: :public_key_not_found
    )
  end

  def update_jwt_public_key_pem(realm_name, jwt_public_key_pem) do
    keyspace = Realm.keyspace_name(realm_name)

    consistency = Consistency.domain_model(:write)

    %{
      group: "auth",
      key: "jwt_public_key_pem",
      value: jwt_public_key_pem,
      value_type: :string
    }
    |> KvStore.insert(prefix: keyspace, consistency: consistency)
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

  def install_trigger_policy_link(_client, _trigger_uuid, nil) do
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

  def retrieve_trigger_uuid(realm_name, trigger_name) do
    keyspace = Realm.keyspace_name(realm_name)

    opts = [
      prefix: keyspace,
      consistency: Consistency.domain_model(:read),
      error: :trigger_not_found
    ]

    with {:ok, uuid} <-
           KvStore.fetch_value("triggers-by-name", trigger_name, :binary, opts) do
      {:ok, :uuid.uuid_to_string(uuid)}
    end
  end

  def delete_trigger_policy_link(_realm_name, _trigger_uuid, nil) do
    :ok
  end

  def delete_trigger_policy_link(realm_name, trigger_uuid, trigger_policy) do
    keyspace = Realm.keyspace_name(realm_name)
    policy_group = "triggers-with-policy-#{trigger_policy}"

    trigger_uuid =
      trigger_uuid
      |> :uuid.uuid_to_string()
      |> to_string()

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

  def delete_trigger(realm_name, trigger_name) do
    with {:ok, trigger_uuid} <- retrieve_trigger_uuid(realm_name, trigger_name) do
      keyspace = Realm.keyspace_name(realm_name)
      trigger_uuid = to_string(trigger_uuid)

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

  def install_new_trigger_policy(realm_name, policy_name, policy_proto) do
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

  def check_trigger_policy_already_present(realm_name, policy_name) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from store in KvStore,
        where: [group: "trigger_policy", key: ^policy_name]

    opts = [
      prefix: keyspace,
      consistency: Consistency.domain_model(:read)
    ]

    Repo.some?(query, opts)
  end

  def check_device_exists(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from device in RealmsDevice,
        select: device.device_id,
        where: [device_id: ^device_id]

    opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read)
    ]

    Repo.some?(query, opts)
  end

  def insert_device_into_deletion_in_progress(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    deletion = %DeletionInProgress{
      device_id: device_id,
      vmq_ack: false,
      dup_start_ack: false,
      dup_end_ack: false
    }

    opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:write)
    ]

    Repo.insert!(deletion, opts)
    :ok
  end

  def retrieve_devices_to_delete!(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read)
    ]

    from(DeletionInProgress)
    |> Repo.all(opts)
    |> Enum.filter(&DeletionInProgress.all_ack?/1)
  end

  def get_device_registration_limit(realm_name) do
    keyspace = Realm.astarte_keyspace_name()

    query =
      from realm in Realm,
        select: realm.device_registration_limit,
        where: [realm_name: ^realm_name]

    opts = [
      prefix: keyspace,
      consistency: Consistency.domain_model(:read),
      error: :realm_not_found
    ]

    Repo.fetch_one(query, opts)
  end

  def get_datastream_maximum_storage_retention(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    opts = [
      prefix: keyspace,
      consistency: Consistency.domain_model(:read),
      error: :fetch_error
    ]

    case KvStore.fetch_value(
           "realm_config",
           "datastream_maximum_storage_retention",
           :integer,
           opts
         ) do
      {:ok, value} -> {:ok, value}
      # not found means default maximum storage retention of 0
      {:error, :fetch_error} -> {:ok, 0}
      error -> error
    end
  end
end
