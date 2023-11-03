#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
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
  require CQEx
  require Logger
  alias Astarte.Core.AstarteReference
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
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
  alias Astarte.Core.Triggers.PolicyProtobuf.PolicyProto
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult
  alias CQEx.Result.SchemaChanged

  @max_batch_queries 32

  @insert_into_interfaces """
    INSERT INTO interfaces
      (name, major_version, minor_version, interface_id, storage_type, storage, type, ownership, aggregation, automaton_transitions, automaton_accepting_states, description, doc)
      VALUES (:name, :major_version, :minor_version, :interface_id, :storage_type, :storage, :type, :ownership, :aggregation, :automaton_transitions, :automaton_accepting_states, :description, :doc)
  """

  @create_datastream_individual_multiinterface_table """
    CREATE TABLE IF NOT EXISTS individual_datastreams (
      device_id uuid,
      interface_id uuid,
      endpoint_id uuid,
      path varchar,
      value_timestamp timestamp,
      reception_timestamp timestamp,
      reception_timestamp_submillis smallint,

      double_value double,
      integer_value int,
      boolean_value boolean,
      longinteger_value bigint,
      string_value varchar,
      binaryblob_value blob,
      datetime_value timestamp,
      doublearray_value list<double>,
      integerarray_value list<int>,
      booleanarray_value list<boolean>,
      longintegerarray_value list<bigint>,
      stringarray_value list<varchar>,
      binaryblobarray_value list<blob>,
      datetimearray_value list<timestamp>,

      PRIMARY KEY((device_id, interface_id, endpoint_id, path), value_timestamp, reception_timestamp, reception_timestamp_submillis)
    )
  """

  @create_interface_table_with_object_aggregation """
    CREATE TABLE :interface_name (
      device_id uuid,
      path varchar,

      :value_timestamp,
      reception_timestamp timestamp,
      reception_timestamp_submillis smallint,
      :columns,

      PRIMARY KEY((device_id, path), :key_timestamp reception_timestamp, reception_timestamp_submillis)
    )
  """

  @query_jwt_public_key_pem """
    SELECT blobAsVarchar(value)
    FROM kv_store
    WHERE group='auth' AND key='jwt_public_key_pem';
  """

  @query_insert_jwt_public_key_pem """
  INSERT INTO kv_store (group, key, value)
  VALUES ('auth', 'jwt_public_key_pem', varcharAsBlob(:pem));
  """

  defp create_one_object_columns_for_mappings(mappings) do
    for %Mapping{endpoint: endpoint, value_type: value_type} <- mappings do
      column_name = CQLUtils.endpoint_to_db_column_name(endpoint)
      cql_type = CQLUtils.mapping_value_type_to_db_type(value_type)
      "#{column_name} #{cql_type}"
    end
    |> Enum.join(~s(,\n))
  end

  defp create_interface_table(
         :individual,
         :multi,
         %InterfaceDescriptor{type: :properties},
         _mappings
       ) do
    {:multi_interface_individual_properties_dbtable, "individual_properties", ""}
  end

  defp create_interface_table(
         :individual,
         :multi,
         %InterfaceDescriptor{type: :datastream},
         _mappings
       ) do
    {:multi_interface_individual_datastream_dbtable, "individual_datastreams",
     @create_datastream_individual_multiinterface_table}
  end

  defp create_interface_table(:object, :one, interface_descriptor, mappings) do
    table_name =
      CQLUtils.interface_name_to_table_name(
        interface_descriptor.name,
        interface_descriptor.major_version
      )

    columns = create_one_object_columns_for_mappings(mappings)

    [%Mapping{explicit_timestamp: explicit_timestamp} | _tail] = mappings

    {value_timestamp, key_timestamp} =
      if explicit_timestamp do
        {"value_timestamp timestamp,", "value_timestamp,"}
      else
        {"", ""}
      end

    create_table_statement =
      @create_interface_table_with_object_aggregation
      |> String.replace(":interface_name", table_name)
      |> String.replace(":value_timestamp", value_timestamp)
      |> String.replace(":columns", columns)
      |> String.replace(":key_timestamp", key_timestamp)

    {:one_object_datastream_dbtable, table_name, create_table_statement}
  end

  defp execute_batch(client, queries) when length(queries) < @max_batch_queries do
    batch = CQEx.cql_query_batch(consistency: :each_quorum, mode: :logged, queries: queries)

    with {:ok, _result} <- DatabaseQuery.call(client, batch) do
      :ok
    else
      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Failed batch due to database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ =
          Logger.warn("Failed batch due to database error: #{inspect(reason)}.", tag: "db_error")

        {:error, :database_error}
    end
  end

  defp execute_batch(client, queries) do
    _ =
      Logger.debug(
        "Trying to run #{inspect(length(queries))} queries, not running in batched mode."
      )

    Enum.reduce_while(queries, :ok, fn query, _acc ->
      with {:ok, _result} <- DatabaseQuery.call(client, query) do
        {:cont, :ok}
      else
        %{acc: _, msg: err_msg} ->
          _ =
            Logger.warn(
              "Failed due to database error: #{err_msg}. Changes will not be undone!",
              tag: "db_error"
            )

          {:halt, {:error, :database_error}}

        {:error, err} ->
          _ =
            Logger.warn(
              "Failed due to database error: #{inspect(err)}. Changes will not be undone!",
              tag: "db_error"
            )

          {:halt, {:error, :database_error}}
      end
    end)
  end

  def check_astarte_health(client, consistency) do
    schema_statement = """
      SELECT count(value)
      FROM astarte.kv_store
      WHERE group='astarte' AND key='schema_version'
    """

    # no-op, just to check if nodes respond
    # no realm name can contain '_', '^'
    realms_statement = """
    SELECT *
    FROM astarte.realms
    WHERE realm_name='_invalid^name_'
    """

    schema_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(schema_statement)
      |> DatabaseQuery.consistency(consistency)

    realms_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(realms_statement)
      |> DatabaseQuery.consistency(consistency)

    with {:ok, result} <- DatabaseQuery.call(client, schema_query),
         ["system.count(value)": _count] <- DatabaseResult.head(result),
         {:ok, _result} <- DatabaseQuery.call(client, realms_query) do
      :ok
    else
      %{acc: _, msg: err_msg} ->
        _ = Logger.warn("Health is not good: #{err_msg}.", tag: "health_check_bad")

        {:error, :health_check_bad}

      {:error, err} ->
        _ = Logger.warn("Health is not good, reason: #{inspect(err)}.", tag: "health_check_bad")

        {:error, :health_check_bad}
    end
  end

  def install_new_interface(client, interface_document, automaton) do
    interface_descriptor = InterfaceDescriptor.from_interface(interface_document)

    %InterfaceDescriptor{
      interface_id: interface_id,
      name: interface_name,
      major_version: major,
      minor_version: minor,
      type: interface_type,
      ownership: interface_ownership,
      aggregation: aggregation
    } = interface_descriptor

    %InterfaceDocument{
      description: description,
      doc: doc
    } = interface_document

    table_type =
      if aggregation == :individual do
        :multi
      else
        :one
      end

    {storage_type, table_name, create_table_statement} =
      create_interface_table(
        aggregation,
        table_type,
        interface_descriptor,
        interface_document.mappings
      )

    {:ok, _} =
      if create_table_statement != "" do
        _ = Logger.info("Creating new interface table.", tag: "create_interface_table")

        {:ok, _res} =
          Xandra.Cluster.run(:xandra, fn conn ->
            CSystem.run_with_schema_agreement(conn, fn ->
              DatabaseQuery.call(client, create_table_statement)
            end)
          end)
      else
        {:ok, nil}
      end

    {transitions, accepting_states_no_ids} = automaton

    transitions_bin = :erlang.term_to_binary(transitions)

    accepting_states_bin =
      accepting_states_no_ids
      |> replace_automaton_acceptings_with_ids(interface_name, major)
      |> :erlang.term_to_binary()

    insert_interface_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@insert_into_interfaces)
      |> DatabaseQuery.put(:name, interface_name)
      |> DatabaseQuery.put(:major_version, major)
      |> DatabaseQuery.put(:minor_version, minor)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.put(:storage_type, StorageType.to_int(storage_type))
      |> DatabaseQuery.put(:storage, table_name)
      |> DatabaseQuery.put(:type, InterfaceType.to_int(interface_type))
      |> DatabaseQuery.put(:ownership, Ownership.to_int(interface_ownership))
      |> DatabaseQuery.put(:aggregation, Aggregation.to_int(aggregation))
      |> DatabaseQuery.put(:automaton_transitions, transitions_bin)
      |> DatabaseQuery.put(:automaton_accepting_states, accepting_states_bin)
      |> DatabaseQuery.put(:description, description)
      |> DatabaseQuery.put(:doc, doc)
      |> DatabaseQuery.consistency(:each_quorum)
      |> DatabaseQuery.convert()

    insert_endpoints =
      for mapping <- interface_document.mappings do
        insert_mapping_query(interface_id, interface_name, major, minor, interface_type, mapping)
        |> DatabaseQuery.convert()
      end

    execute_batch(client, insert_endpoints ++ [insert_interface_query])
  end

  defp insert_mapping_query(interface_id, interface_name, major, minor, interface_type, mapping) do
    insert_mapping_statement = """
    INSERT INTO endpoints
    (
      interface_id, endpoint_id, interface_name, interface_major_version, interface_minor_version,
      interface_type, endpoint, value_type, reliability, retention, database_retention_policy,
      database_retention_ttl, expiry, allow_unset, explicit_timestamp, description, doc
    )
    VALUES (
      :interface_id, :endpoint_id, :interface_name, :interface_major_version, :interface_minor_version,
      :interface_type, :endpoint, :value_type, :reliability, :retention, :database_retention_policy,
      :database_retention_ttl, :expiry, :allow_unset, :explicit_timestamp, :description, :doc
    )
    """

    DatabaseQuery.new()
    |> DatabaseQuery.statement(insert_mapping_statement)
    |> DatabaseQuery.put(:interface_id, interface_id)
    |> DatabaseQuery.put(:endpoint_id, mapping.endpoint_id)
    |> DatabaseQuery.put(:interface_name, interface_name)
    |> DatabaseQuery.put(:interface_major_version, major)
    |> DatabaseQuery.put(:interface_minor_version, minor)
    |> DatabaseQuery.put(:interface_type, InterfaceType.to_int(interface_type))
    |> DatabaseQuery.put(:endpoint, mapping.endpoint)
    |> DatabaseQuery.put(:value_type, ValueType.to_int(mapping.value_type))
    |> DatabaseQuery.put(:reliability, Reliability.to_int(mapping.reliability))
    |> DatabaseQuery.put(:retention, Retention.to_int(mapping.retention))
    |> DatabaseQuery.put(
      :database_retention_policy,
      DatabaseRetentionPolicy.to_int(mapping.database_retention_policy)
    )
    |> DatabaseQuery.put(:database_retention_ttl, mapping.database_retention_ttl)
    |> DatabaseQuery.put(:expiry, mapping.expiry)
    |> DatabaseQuery.put(:allow_unset, mapping.allow_unset)
    |> DatabaseQuery.put(:explicit_timestamp, mapping.explicit_timestamp)
    |> DatabaseQuery.put(:description, mapping.description)
    |> DatabaseQuery.put(:doc, mapping.doc)
    |> DatabaseQuery.consistency(:each_quorum)
  end

  # TODO: this was needed when Cassandra used to generate endpoint IDs
  # it might be a good idea to drop this and generate those IDs in A.C.Mapping.EndpointsAutomaton
  defp replace_automaton_acceptings_with_ids(accepting_states, interface_name, major) do
    Enum.reduce(accepting_states, %{}, fn state, new_states ->
      {state_index, endpoint} = state

      Map.put(new_states, state_index, CQLUtils.endpoint_id(interface_name, major, endpoint))
    end)
  end

  def update_interface(client, interface_descriptor, new_mappings, automaton, description, doc) do
    %InterfaceDescriptor{
      name: interface_name,
      major_version: major,
      minor_version: minor,
      type: interface_type,
      interface_id: interface_id
    } = interface_descriptor

    {automaton_transitions, automaton_accepting_states_no_ids} = automaton

    automaton_accepting_states_bin =
      automaton_accepting_states_no_ids
      |> replace_automaton_acceptings_with_ids(interface_name, major)
      |> :erlang.term_to_binary()

    automaton_transitions_bin = :erlang.term_to_binary(automaton_transitions)

    update_interface_statement = """
    UPDATE interfaces
    SET minor_version=:minor_version, automaton_accepting_states=:automaton_accepting_states,
      automaton_transitions = :automaton_transitions, description = :description, doc = :doc
    WHERE name=:name AND major_version=:major_version
    """

    update_interface_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(update_interface_statement)
      |> DatabaseQuery.put(:name, interface_name)
      |> DatabaseQuery.put(:major_version, major)
      |> DatabaseQuery.put(:minor_version, minor)
      |> DatabaseQuery.put(:automaton_accepting_states, automaton_accepting_states_bin)
      |> DatabaseQuery.put(:automaton_transitions, automaton_transitions_bin)
      |> DatabaseQuery.put(:description, description)
      |> DatabaseQuery.put(:doc, doc)
      |> DatabaseQuery.consistency(:each_quorum)
      |> DatabaseQuery.convert()

    insert_mapping_queries =
      for mapping <- new_mappings do
        insert_mapping_query(interface_id, interface_name, major, minor, interface_type, mapping)
        |> DatabaseQuery.convert()
      end

    execute_batch(client, insert_mapping_queries ++ [update_interface_query])
  end

  def update_interface_storage(_client, _interface_descriptor, []) do
    # No new mappings, nothing to do
    :ok
  end

  def update_interface_storage(
        client,
        %InterfaceDescriptor{storage_type: :one_object_datastream_dbtable, storage: table_name} =
          _interface_descriptor,
        new_mappings
      ) do
    add_cols = create_one_object_columns_for_mappings(new_mappings)

    _ =
      Logger.debug("Interface update: going to add #{inspect(add_cols)} to #{table_name}.",
        tag: "db_interface_add_table_cols"
      )

    update_storage_statement = """
    ALTER TABLE #{table_name}
    ADD (#{add_cols})
    """

    with {:ok, %SchemaChanged{change_type: :updated} = _result} <-
           DatabaseQuery.call(client, update_storage_statement) do
      :ok
    else
      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Database error: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def update_interface_storage(_client, _interface_descriptor, _new_mappings) do
    :ok
  end

  def delete_interface(client, interface_name, interface_major_version) do
    _ =
      Logger.info("Delete interface.",
        interface: interface_name,
        interface_major: interface_major_version,
        tag: "db_delete_interface"
      )

    delete_endpoints_statement = "DELETE FROM endpoints WHERE interface_id=:interface_id"

    interface_id = CQLUtils.interface_id(interface_name, interface_major_version)

    delete_endpoints =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_endpoints_statement)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.consistency(:each_quorum)

    delete_interface_statement =
      "DELETE FROM interfaces WHERE name=:name AND major_version=:major"

    delete_interface =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_interface_statement)
      |> DatabaseQuery.put(:name, interface_name)
      |> DatabaseQuery.put(:major, interface_major_version)
      |> DatabaseQuery.consistency(:each_quorum)

    # TODO: use a batch here
    with {:ok, _result} <- DatabaseQuery.call(client, delete_endpoints),
         {:ok, _result} <- DatabaseQuery.call(client, delete_interface) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.error(
            "Database error while deleting #{interface_name}, reason: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  def delete_interface_storage(
        client,
        %InterfaceDescriptor{
          storage_type: :one_object_datastream_dbtable,
          storage: table_name
        } = _interface_descriptor
      ) do
    delete_statement = "DROP TABLE IF EXISTS #{table_name}"

    with {:ok, _res} <- DatabaseQuery.call(client, delete_statement) do
      _ = Logger.info("Deleted #{table_name} table.", tag: "db_delete_interface_table")
      :ok
    else
      {:error, reason} ->
        _ = Logger.warn("Database error: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def delete_interface_storage(client, %InterfaceDescriptor{} = interface_descriptor) do
    with {:ok, result} <- devices_with_data_on_interface(client, interface_descriptor.name) do
      Enum.reduce_while(result, :ok, fn [key: encoded_device_id], _acc ->
        with {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
             :ok <- delete_values(client, device_id, interface_descriptor) do
          {:cont, :ok}
        else
          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)
    end
  end

  def is_any_device_using_interface?(client, interface_name) do
    devices_statement = "SELECT key FROM kv_store WHERE group=:group_name LIMIT 1"

    devices_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(devices_statement)
      |> DatabaseQuery.put(:group_name, "devices-by-interface-#{interface_name}-v0")
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(client, devices_query),
         [key: _device_id] <- DatabaseResult.head(result) do
      {:ok, true}
    else
      :empty_dataset ->
        {:ok, false}

      {:error, reason} ->
        _ = Logger.warn("Database error: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def devices_with_data_on_interface(client, interface_name) do
    devices_statement = "SELECT key FROM kv_store WHERE group=:group_name"

    devices_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(devices_statement)
      |> DatabaseQuery.put(:group_name, "devices-with-data-on-interface-#{interface_name}-v0")
      |> DatabaseQuery.consistency(:quorum)

    DatabaseQuery.call(client, devices_query)
  end

  def delete_devices_with_data_on_interface(client, interface_name) do
    devices_statement = "DELETE FROM kv_store WHERE group=:group_name"

    devices_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(devices_statement)
      |> DatabaseQuery.put(:group_name, "devices-with-data-on-interface-#{interface_name}-v0")
      |> DatabaseQuery.consistency(:each_quorum)

    with {:ok, _result} <- DatabaseQuery.call(client, devices_query) do
      :ok
    else
      {:error, reason} ->
        _ = Logger.warn("Database error: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def delete_values(
        client,
        device_id,
        %InterfaceDescriptor{
          interface_id: interface_id,
          storage_type: :multi_interface_individual_properties_dbtable,
          storage: table_name
        } = _interface_descriptor
      ) do
    delete_values_statement = """
    DELETE
    FROM #{table_name}
    WHERE device_id=:device_id AND interface_id=:interface_id
    """

    delete_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_values_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.consistency(:each_quorum)

    with {:ok, _res} <- DatabaseQuery.call(client, delete_query) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.warn("Database error: cannot delete values. Reason: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  def delete_values(
        client,
        device_id,
        %InterfaceDescriptor{
          storage_type: :multi_interface_individual_datastream_dbtable
        } = interface_descriptor
      ) do
    with {:ok, result} <-
           fetch_all_paths_and_endpoint_ids(client, device_id, interface_descriptor),
         :ok <- delete_all_paths_values(client, device_id, interface_descriptor, result) do
      delete_all_paths(client, device_id, interface_descriptor)
    end
  end

  defp delete_all_paths_values(client, device_id, interface_descriptor, all_paths) do
    Enum.reduce_while(all_paths, :ok, fn [endpoint_id: endpoint_id, path: path], _acc ->
      with :ok <- delete_path_values(client, device_id, interface_descriptor, endpoint_id, path) do
        {:cont, :ok}
      else
        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  def delete_path_values(
        client,
        device_id,
        %InterfaceDescriptor{
          interface_id: interface_id,
          storage_type: :multi_interface_individual_datastream_dbtable,
          storage: table_name
        } = _interface_descriptor,
        endpoint_id,
        path
      ) do
    delete_path_values_statement = """
    DELETE
    FROM #{table_name}
    WHERE device_id=:device_id AND interface_id=:interface_id
      AND endpoint_id=:endpoint_id AND path=:path
    """

    delete_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_path_values_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, _res} <- DatabaseQuery.call(client, delete_query) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.warn("Database error: cannot delete path values. Reason: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  defp fetch_all_paths_and_endpoint_ids(
         client,
         device_id,
         %InterfaceDescriptor{
           interface_id: interface_id,
           storage_type: :multi_interface_individual_datastream_dbtable
         } = _interface_descriptor
       ) do
    all_paths_statement = """
    SELECT endpoint_id, path
    FROM individual_properties
    WHERE device_id=:device_id AND interface_id=:interface_id
    """

    all_paths_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(all_paths_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.consistency(:quorum)

    DatabaseQuery.call(client, all_paths_query)
  end

  defp delete_all_paths(
         client,
         device_id,
         %InterfaceDescriptor{
           interface_id: interface_id,
           storage_type: :multi_interface_individual_datastream_dbtable
         } = _interface_descriptor
       ) do
    delete_paths_statement = """
    DELETE
    FROM individual_properties
    WHERE device_id=:device_id AND interface_id=:interface_id
    """

    all_paths_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_paths_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.consistency(:each_quorum)

    with {:ok, _result} <- DatabaseQuery.call(client, all_paths_query) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.warn("Database error while deleting all paths: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  def interface_available_versions(client, interface_name) do
    interface_versions_statement = """
    SELECT major_version, minor_version
    FROM interfaces
    WHERE name = :interface_name
    """

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(interface_versions_statement)
      |> DatabaseQuery.put(:interface_name, interface_name)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(client, query),
         [head | tail] <- Enum.to_list(result) do
      {:ok, [head | tail]}
    else
      [] ->
        {:error, :interface_not_found}

      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Database error: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def is_interface_major_available?(client, interface_name, interface_major) do
    interface_available_major_statement = """
    SELECT COUNT(*)
    FROM interfaces
    WHERE name = :interface_name AND major_version = :interface_major
    """

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(interface_available_major_statement)
      |> DatabaseQuery.put(:interface_name, interface_name)
      |> DatabaseQuery.put(:interface_major, interface_major)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(client, query),
         [count: count] <- DatabaseResult.head(result) do
      {:ok, count != 0}
    else
      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Database error: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  defp normalize_interface_name(interface_name) do
    String.replace(interface_name, "-", "")
    |> String.downcase()
  end

  def check_astarte_health(consistency) do
    schema_statement = """
      SELECT count(value)
      FROM astarte.kv_store
      WHERE group='astarte' AND key='schema_version'
    """

    # no-op, just to check if nodes respond
    # no realm name can contain '_', '^'
    realms_statement = """
    SELECT *
    FROM astarte.realms
    WHERE realm_name='_invalid^name_'
    """

    with {:ok, %Xandra.Page{} = page} <-
           Xandra.Cluster.execute(:xandra, schema_statement, %{}, consistency: consistency),
         {:ok, _} <- Enum.fetch(page, 0),
         {:ok, %Xandra.Page{} = _page} <-
           Xandra.Cluster.execute(:xandra, realms_statement, %{}, consistency: consistency) do
      :ok
    else
      :error ->
        _ =
          Logger.warn("Cannot retrieve health query data.",
            tag: "health_check_error"
          )

        {:error, :health_check_bad}

      {:error, %Xandra.Error{} = err} ->
        _ =
          Logger.warn("Database error, health is not good: #{inspect(err)}.",
            tag: "health_check_database_error"
          )

        {:error, :health_check_bad}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warn("Database error, health is not good: #{inspect(err)}.",
            tag: "health_check_database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  def check_interface_name_collision(client, interface_name) do
    normalized_interface = normalize_interface_name(interface_name)

    all_names_statement = """
    SELECT DISTINCT name
    FROM interfaces
    """

    all_names_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(all_names_statement)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(client, all_names_query) do
      Enum.reduce_while(result, :ok, fn row, acc ->
        if normalize_interface_name(row[:name]) == normalized_interface do
          if row[:name] == interface_name do
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
    else
      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("Database error: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def fetch_interface(client, interface_name, interface_major) do
    # TODO: replace with retrieve_interface_row
    all_interface_cols_statement = """
    SELECT *
    FROM interfaces
    WHERE name = :name AND major_version = :major_version
    """

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(all_interface_cols_statement)
      |> DatabaseQuery.put(:name, interface_name)
      |> DatabaseQuery.put(:major_version, interface_major)
      |> DatabaseQuery.consistency(:quorum)

    # TODO: replace with Astarte.DataAccess.Mappings.fetch_interface_mappings
    all_endpoints_cols_statement = """
    SELECT *
    FROM endpoints
    WHERE interface_id = :interface_id
    """

    endpoints_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(all_endpoints_cols_statement)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(client, query),
         interface_row when is_list(interface_row) <- DatabaseResult.head(result),
         {:ok, interface_id} <- Keyword.fetch(interface_row, :interface_id),
         endpoints_query <- DatabaseQuery.put(endpoints_query, :interface_id, interface_id),
         {:ok, endpoints_result} <- DatabaseQuery.call(client, endpoints_query) do
      mappings =
        Enum.map(endpoints_result, fn mapping_row ->
          %{
            endpoint_id: endpoint_id,
            allow_unset: allow_unset,
            database_retention_policy: database_retention_policy,
            database_retention_ttl: database_retention_ttl,
            explicit_timestamp: explicit_timestamp,
            endpoint: endpoint,
            expiry: expiry,
            reliability: reliability,
            retention: retention,
            value_type: value_type,
            description: mapping_description,
            doc: mapping_doc
          } = Enum.into(mapping_row, %{})

          %Mapping{
            endpoint_id: endpoint_id,
            allow_unset: allow_unset,
            database_retention_policy:
              database_retention_policy_from_maybe_int(database_retention_policy),
            database_retention_ttl: database_retention_ttl,
            explicit_timestamp: explicit_timestamp,
            endpoint: endpoint,
            expiry: expiry,
            reliability: Reliability.from_int(reliability),
            retention: Retention.from_int(retention),
            value_type: ValueType.from_int(value_type),
            description: mapping_description,
            doc: mapping_doc
          }
        end)

      %{
        name: name,
        major_version: major_version,
        minor_version: minor_version,
        interface_id: interface_id,
        type: type,
        ownership: ownership,
        aggregation: aggregation,
        description: description,
        doc: doc
      } = Enum.into(interface_row, %{})

      interface = %InterfaceDocument{
        name: name,
        major_version: major_version,
        minor_version: minor_version,
        interface_id: interface_id,
        type: InterfaceType.from_int(type),
        ownership: Ownership.from_int(ownership),
        aggregation: Aggregation.from_int(aggregation),
        mappings: mappings,
        description: description,
        doc: doc
      }

      {:ok, interface}
    else
      :empty_dataset ->
        {:error, :interface_not_found}

      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Failed, reason: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  defp database_retention_policy_from_maybe_int(database_retention_policy) do
    case database_retention_policy do
      nil -> :no_ttl
      any_int -> DatabaseRetentionPolicy.from_int(database_retention_policy)
    end
  end

  def get_interfaces_list(client) do
    interfaces_list_statement = """
    SELECT DISTINCT name FROM interfaces
    """

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(interfaces_list_statement)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(client, query) do
      list =
        Enum.map(result, fn row ->
          Keyword.fetch!(row, :name)
        end)

      {:ok, list}
    else
      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ =
          Logger.warn("Database error: failed with reason: #{inspect(reason)}.", tag: "db_error")

        {:error, :database_error}
    end
  end

  def has_interface_simple_triggers?(db_client, object_id) do
    # FIXME: hardcoded object type here
    simple_triggers_statement = """
    SELECT COUNT(*)
    FROM simple_triggers
    WHERE object_id=:object_id AND object_type=2
    """

    simple_triggers_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(simple_triggers_statement)
      |> DatabaseQuery.put(:object_id, object_id)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(db_client, simple_triggers_query),
         [count: count] <- DatabaseResult.head(result) do
      if count != 0 do
        {:ok, true}
      else
        {:ok, false}
      end
    else
      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Failed with reason: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def get_jwt_public_key_pem(client) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@query_jwt_public_key_pem)

    with {:ok, result} <- DatabaseQuery.call(client, query),
         ["system.blobasvarchar(value)": pem] <- DatabaseResult.head(result) do
      {:ok, pem}
    else
      _ ->
        {:error, :public_key_not_found}
    end
  end

  def update_jwt_public_key_pem(client, jwt_public_key_pem) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@query_insert_jwt_public_key_pem)
      |> DatabaseQuery.put(:pem, jwt_public_key_pem)

    case DatabaseQuery.call(client, query) do
      {:ok, _res} ->
        :ok

      _ ->
        {:error, :cant_update_public_key}
    end
  end

  def install_trigger(client, trigger) do
    # TODO: use IF NOT EXISTS
    insert_by_name_query_statement =
      "INSERT INTO kv_store (group, key, value) VALUES ('triggers-by-name', :trigger_name, uuidAsBlob(:trigger_uuid));"

    insert_by_name_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_by_name_query_statement)
      |> DatabaseQuery.put(:trigger_name, trigger.name)
      |> DatabaseQuery.put(:trigger_uuid, trigger.trigger_uuid)

    # TODO: use IF NOT EXISTS
    insert_query_statement =
      "INSERT INTO kv_store (group, key, value) VALUES ('triggers', :trigger_uuid, :trigger_data);"

    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_query_statement)
      |> DatabaseQuery.put(:trigger_uuid, :uuid.uuid_to_string(trigger.trigger_uuid))
      |> DatabaseQuery.put(:trigger_data, Trigger.encode(trigger))

    # TODO: Batch queries
    with {:ok, _res} <- DatabaseQuery.call(client, insert_by_name_query),
         {:ok, _res} <- DatabaseQuery.call(client, insert_query) do
      :ok
    else
      not_ok ->
        _ = Logger.warn("Database error: #{inspect(not_ok)}.", tag: "db_error")
        {:error, :cannot_install_trigger}
    end
  end

  def install_simple_trigger(
        client,
        object_id,
        object_type,
        parent_trigger_id,
        simple_trigger_id,
        simple_trigger,
        trigger_target
      ) do
    insert_simple_trigger_statement = """
    INSERT INTO simple_triggers
    (object_id, object_type, parent_trigger_id, simple_trigger_id, trigger_data, trigger_target)
    VALUES (:object_id, :object_type, :parent_trigger_id, :simple_trigger_id, :simple_trigger_data, :trigger_target_data);
    """

    insert_simple_trigger_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_simple_trigger_statement)
      |> DatabaseQuery.put(:object_id, object_id)
      |> DatabaseQuery.put(:object_type, object_type)
      |> DatabaseQuery.put(:parent_trigger_id, parent_trigger_id)
      |> DatabaseQuery.put(:simple_trigger_id, simple_trigger_id)
      |> DatabaseQuery.put(:simple_trigger_data, SimpleTriggerContainer.encode(simple_trigger))
      |> DatabaseQuery.put(:trigger_target_data, TriggerTargetContainer.encode(trigger_target))

    astarte_ref = %AstarteReference{
      object_type: object_type,
      object_uuid: object_id
    }

    insert_simple_trigger_by_uuid_statement =
      "INSERT INTO kv_store (group, key, value) VALUES ('simple-triggers-by-uuid', :simple_trigger_id, :astarte_ref);"

    insert_simple_trigger_by_uuid_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_simple_trigger_by_uuid_statement)
      |> DatabaseQuery.put(:simple_trigger_id, :uuid.uuid_to_string(simple_trigger_id))
      |> DatabaseQuery.put(:astarte_ref, AstarteReference.encode(astarte_ref))

    with {:ok, _res} <- DatabaseQuery.call(client, insert_simple_trigger_query),
         {:ok, _res} <- DatabaseQuery.call(client, insert_simple_trigger_by_uuid_query) do
      :ok
    else
      not_ok ->
        _ = Logger.warn("Database error: #{inspect(not_ok)}.", tag: "db_error")
        {:error, :cannot_install_simple_trigger}
    end
  end

  def install_trigger_policy_link(_client, _trigger_uuid, nil) do
    :ok
  end

  def install_trigger_policy_link(client, trigger_uuid, trigger_policy) do
    insert_trigger_with_policy_statement =
      "INSERT INTO kv_store (group, key, value) VALUES (:policy_group, :trigger_uuid, uuidAsBlob(:t_uuid_to_be_converted))"

    insert_trigger_with_policy_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_trigger_with_policy_statement)
      |> DatabaseQuery.put(:policy_group, "triggers-with-policy-#{trigger_policy}")
      |> DatabaseQuery.put(:trigger_uuid, :uuid.uuid_to_string(trigger_uuid))
      |> DatabaseQuery.put(:t_uuid_to_be_converted, :uuid.uuid_to_string(trigger_uuid))

    insert_trigger_to_policy_statement =
      "INSERT INTO kv_store (group, key, value) VALUES ('trigger_to_policy',  :trigger_uuid, :trigger_policy);"

    insert_trigger_to_policy_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_trigger_to_policy_statement)
      |> DatabaseQuery.put(:trigger_uuid, :uuid.uuid_to_string(trigger_uuid))
      |> DatabaseQuery.put(:trigger_policy, trigger_policy)

    with {:ok, _result} <- DatabaseQuery.call(client, insert_trigger_with_policy_query),
         {:ok, _result} <- DatabaseQuery.call(client, insert_trigger_to_policy_query) do
      :ok
    else
      not_ok ->
        _ = Logger.warn("Database error: #{inspect(not_ok)}.", tag: "db_error")
        {:error, :cannot_install_trigger_policy_link}
    end
  end

  def retrieve_trigger_uuid(client, trigger_name, format \\ :string) do
    trigger_uuid_query_statement =
      "SELECT value FROM kv_store WHERE group='triggers-by-name' AND key=:trigger_name;"

    trigger_uuid_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(trigger_uuid_query_statement)
      |> DatabaseQuery.put(:trigger_name, trigger_name)

    with {:ok, result} <- DatabaseQuery.call(client, trigger_uuid_query),
         [value: trigger_uuid] <- DatabaseResult.head(result) do
      case format do
        :string ->
          {:ok, :uuid.uuid_to_string(trigger_uuid)}

        :bytes ->
          {:ok, trigger_uuid}
      end
    else
      :empty_dataset ->
        {:error, :trigger_not_found}

      not_ok ->
        _ = Logger.warn("Database error: #{inspect(not_ok)}.", tag: "db_error")
        {:error, :cannot_retrieve_trigger_uuid}
    end
  end

  def delete_trigger_policy_link(_client, _trigger_uuid, nil) do
    :ok
  end

  def delete_trigger_policy_link(client, trigger_uuid, trigger_policy) do
    delete_trigger_with_policy_statement =
      "DELETE FROM kv_store WHERE group=:policy_group AND key=:trigger_uuid;"

    delete_trigger_with_policy_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_trigger_with_policy_statement)
      |> DatabaseQuery.put(:policy_group, "triggers-with-policy-#{trigger_policy}")
      |> DatabaseQuery.put(:trigger_uuid, :uuid.uuid_to_string(trigger_uuid))

    delete_trigger_to_policy_statement =
      "DELETE FROM kv_store WHERE group='trigger_to_policy' AND key=:trigger_uuid;"

    delete_trigger_to_policy_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_trigger_to_policy_statement)
      |> DatabaseQuery.put(:trigger_uuid, :uuid.uuid_to_string(trigger_uuid))

    with {:ok, _result} <- DatabaseQuery.call(client, delete_trigger_with_policy_query),
         {:ok, _result} <- DatabaseQuery.call(client, delete_trigger_to_policy_query) do
      :ok
    else
      not_ok ->
        _ = Logger.warn("Database error: #{inspect(not_ok)}.", tag: "db_error")
        {:error, :cannot_delete_trigger_policy_link}
    end
  end

  def delete_trigger(client, trigger_name) do
    with {:ok, trigger_uuid} <- retrieve_trigger_uuid(client, trigger_name) do
      delete_trigger_by_name_statement =
        "DELETE FROM kv_store WHERE group='triggers-by-name' AND key=:trigger_name;"

      delete_trigger_by_name_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(delete_trigger_by_name_statement)
        |> DatabaseQuery.put(:trigger_name, trigger_name)

      delete_trigger_statement =
        "DELETE FROM kv_store WHERE group='triggers' AND key=:trigger_uuid;"

      delete_trigger_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(delete_trigger_statement)
        |> DatabaseQuery.put(:trigger_uuid, trigger_uuid)

      with {:ok, _result} <- DatabaseQuery.call(client, delete_trigger_query),
           {:ok, _result} <- DatabaseQuery.call(client, delete_trigger_by_name_query) do
        :ok
      else
        not_ok ->
          _ = Logger.warn("Database error: #{inspect(not_ok)}.", tag: "db_error")
          {:error, :cannot_delete_trigger}
      end
    end
  end

  def get_triggers_list(client) do
    triggers_list_statement = "SELECT key FROM kv_store WHERE group = 'triggers-by-name';"

    query_result =
      with {:ok, result} <- DatabaseQuery.call(client, triggers_list_statement),
           triggers_rows <- Enum.to_list(result) do
        for trigger <- triggers_rows do
          trigger[:key]
        end
      else
        not_ok ->
          _ = Logger.warn("Database error: #{inspect(not_ok)}.", tag: "db_error")
          {:error, :cannot_list_triggers}
      end

    {:ok, query_result}
  end

  def retrieve_trigger(client, trigger_name) do
    with {:ok, trigger_uuid} <- retrieve_trigger_uuid(client, trigger_name) do
      retrieve_trigger_statement =
        "SELECT value FROM kv_store WHERE group='triggers' AND key=:trigger_uuid;"

      retrieve_trigger_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(retrieve_trigger_statement)
        |> DatabaseQuery.put(:trigger_uuid, trigger_uuid)

      with {:ok, result} <- DatabaseQuery.call(client, retrieve_trigger_query),
           [value: trigger_data] <- DatabaseResult.head(result) do
        {:ok, Trigger.decode(trigger_data)}
      else
        :empty_dataset ->
          {:error, :trigger_not_found}

        not_ok ->
          _ = Logger.warn("Database error: #{inspect(not_ok)}.", tag: "db_error")
          {:error, :cannot_retrieve_trigger}
      end
    end
  end

  # TODO: simple_trigger_uuid is required due how we made the compound key
  # should we move simple_trigger_uuid to the first part of the key?
  def retrieve_tagged_simple_trigger(client, parent_trigger_uuid, simple_trigger_uuid) do
    with %{object_uuid: object_id, object_type: object_type} <-
           retrieve_simple_trigger_astarte_ref(client, simple_trigger_uuid) do
      retrieve_simple_trigger_statement = """
      SELECT trigger_data
      FROM simple_triggers
      WHERE object_id=:object_id AND object_type=:object_type AND
            parent_trigger_id=:parent_trigger_id AND simple_trigger_id=:simple_trigger_id
      """

      retrieve_simple_trigger_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(retrieve_simple_trigger_statement)
        |> DatabaseQuery.put(:object_id, object_id)
        |> DatabaseQuery.put(:object_type, object_type)
        |> DatabaseQuery.put(:parent_trigger_id, parent_trigger_uuid)
        |> DatabaseQuery.put(:simple_trigger_id, simple_trigger_uuid)

      with {:ok, result} <- DatabaseQuery.call(client, retrieve_simple_trigger_query),
           [trigger_data: trigger_data] <- DatabaseResult.head(result) do
        {
          :ok,
          %TaggedSimpleTrigger{
            object_id: object_id,
            object_type: object_type,
            simple_trigger_container: SimpleTriggerContainer.decode(trigger_data)
          }
        }
      else
        not_ok ->
          _ =
            Logger.warn("Possible inconsistency found: database error: #{inspect(not_ok)}.",
              tag: "db_error"
            )

          {:error, :cannot_retrieve_simple_trigger}
      end
    else
      :empty_dataset ->
        {:error, :simple_trigger_not_found}

      not_ok ->
        _ = Logger.warn("Database error: #{inspect(not_ok)}.", tag: "db_error")
        {:error, :cannot_retrieve_simple_trigger}
    end
  end

  def delete_simple_trigger(client, parent_trigger_uuid, simple_trigger_uuid) do
    with %{object_uuid: object_id, object_type: object_type} <-
           retrieve_simple_trigger_astarte_ref(client, simple_trigger_uuid) do
      delete_simple_trigger_statement = """
      DELETE FROM simple_triggers
      WHERE object_id=:object_id AND object_type=:object_type AND
            parent_trigger_id=:parent_trigger_id AND simple_trigger_id=:simple_trigger_id
      """

      delete_simple_trigger_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(delete_simple_trigger_statement)
        |> DatabaseQuery.put(:object_id, object_id)
        |> DatabaseQuery.put(:object_type, object_type)
        |> DatabaseQuery.put(:parent_trigger_id, parent_trigger_uuid)
        |> DatabaseQuery.put(:simple_trigger_id, simple_trigger_uuid)

      delete_astarte_ref_statement =
        "DELETE FROM kv_store WHERE group='simple-triggers-by-uuid' AND key=:simple_trigger_uuid;"

      delete_astarte_ref_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(delete_astarte_ref_statement)
        |> DatabaseQuery.put(:simple_trigger_uuid, :uuid.uuid_to_string(simple_trigger_uuid))

      with {:ok, _result} <- DatabaseQuery.call(client, delete_simple_trigger_query),
           {:ok, _result} <- DatabaseQuery.call(client, delete_astarte_ref_query) do
        :ok
      else
        not_ok ->
          _ = Logger.warn("Database error: #{inspect(not_ok)}.", tag: "db_error")
          {:error, :cannot_delete_simple_trigger}
      end
    end
  end

  defp retrieve_simple_trigger_astarte_ref(client, simple_trigger_uuid) do
    retrieve_astarte_ref_statement =
      "SELECT value FROM kv_store WHERE group='simple-triggers-by-uuid' AND key=:simple_trigger_uuid;"

    retrieve_astarte_ref_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(retrieve_astarte_ref_statement)
      |> DatabaseQuery.put(:simple_trigger_uuid, :uuid.uuid_to_string(simple_trigger_uuid))

    with {:ok, result} <- DatabaseQuery.call(client, retrieve_astarte_ref_query),
         [value: astarte_ref_blob] <- DatabaseResult.head(result) do
      AstarteReference.decode(astarte_ref_blob)
    else
      :empty_dataset ->
        {:error, :trigger_not_found}

      not_ok ->
        _ = Logger.warn("Database error: #{inspect(not_ok)}.", tag: "db_error")

        {:error, :cannot_retrieve_simple_trigger}
    end
  end

  def install_new_trigger_policy(client, policy_name, policy_proto) do
    insert_query_statement =
      "INSERT INTO kv_store (group, key, value) VALUES ('trigger_policy', :policy_name, :policy_container);"

    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_query_statement)
      |> DatabaseQuery.put(:policy_name, policy_name)
      |> DatabaseQuery.put(:policy_container, policy_proto)

    with {:ok, _res} <- DatabaseQuery.call(client, insert_query) do
      :ok
    else
      not_ok ->
        _ = Logger.warn("Database error: #{inspect(not_ok)}.", tag: "db_error")
        {:error, :cannot_install_trigger_policy}
    end
  end

  def get_trigger_policies_list(client) do
    trigger_policies_list_statement = """
    SELECT key FROM kv_store WHERE group=:group_name
    """

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(trigger_policies_list_statement)
      |> DatabaseQuery.put(:group_name, "trigger_policy")
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(client, query) do
      list =
        Enum.map(result, fn row ->
          Keyword.fetch!(row, :key)
        end)

      {:ok, list}
    else
      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ =
          Logger.warn("Database error: failed with reason: #{inspect(reason)}.", tag: "db_error")

        {:error, :database_error}
    end
  end

  def fetch_trigger_policy(client, policy_name) do
    policy_cols_statement = """
    SELECT value
    FROM kv_store
    WHERE group=:group_name and key=:policy_name
    """

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(policy_cols_statement)
      |> DatabaseQuery.put(:group_name, "trigger_policy")
      |> DatabaseQuery.put(:policy_name, policy_name)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(client, query),
         policy_row when is_list(policy_row) <- DatabaseResult.head(result),
         {:ok, container} <- Keyword.fetch(policy_row, :value) do
      {:ok, container}
    else
      :empty_dataset ->
        {:error, :policy_not_found}

      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Failed, reason: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def check_policy_has_triggers(client, policy_name) do
    devices_statement = "SELECT key FROM kv_store WHERE group=:group_name LIMIT 1"

    devices_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(devices_statement)
      |> DatabaseQuery.put(:group_name, "triggers-with-policy-#{policy_name}")
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(client, devices_query),
         [key: _device_id] <- DatabaseResult.head(result) do
      {:ok, true}
    else
      :empty_dataset ->
        {:ok, false}

      {:error, reason} ->
        _ =
          Logger.error(
            "Database error while checking #{policy_name}, reason: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  def delete_trigger_policy(client, policy_name) do
    _ =
      Logger.info("Delete trigger policy.",
        policy_name: policy_name,
        tag: "db_delete_trigger_policy"
      )

    delete_policy_statement =
      "DELETE FROM kv_store WHERE group= :group_name AND key= :policy_name"

    delete_policy =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_policy_statement)
      |> DatabaseQuery.put(:group_name, "trigger_policy")
      |> DatabaseQuery.put(:policy_name, policy_name)
      |> DatabaseQuery.consistency(:each_quorum)

    # TODO check warning
    delete_triggers_with_policy_group_statement = "DELETE FROM kv_store WHERE group=:group_name"

    delete_triggers_with_policy_group_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_triggers_with_policy_group_statement)
      |> DatabaseQuery.put(:group_name, "triggers-with-policy-#{policy_name}")
      |> DatabaseQuery.consistency(:each_quorum)

    delete_trigger_to_policy_statement = "DELETE FROM kv_store WHERE group=:group_name;"

    delete_trigger_to_policy_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_trigger_to_policy_statement)
      |> DatabaseQuery.put(:group_name, "trigger_to_policy")

    with {:ok, _result} <- DatabaseQuery.call(client, delete_policy),
         {:ok, _result} <- DatabaseQuery.call(client, delete_triggers_with_policy_group_query),
         {:ok, _result} <- DatabaseQuery.call(client, delete_trigger_to_policy_query) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.error(
            "Database error while deleting #{policy_name}, reason: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  def check_trigger_policy_already_present(client, policy_name) do
    policy_cols_statement = """
    SELECT COUNT(*)
    FROM kv_store
    WHERE group= :group_name and key= :policy_name
    """

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(policy_cols_statement)
      |> DatabaseQuery.put(:group_name, "trigger_policy")
      |> DatabaseQuery.put(:policy_name, policy_name)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(client, query),
         [count: 0] <- DatabaseResult.head(result) do
      {:ok, false}
    else
      [count: _] ->
        {:ok, true}

      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Database error: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def check_device_exists(realm_name, device_id) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_check_device_exists(&1, realm_name, device_id)
    )
  end

  defp do_check_device_exists(conn, realm_name, device_id) do
    # TODO: validate realm name
    statement = """
    SELECT COUNT (*)
    FROM #{realm_name}.devices
    WHERE device_id = :device_id
    """

    params = %{device_id: device_id}

    with {:ok, prepared} <- Xandra.prepare(conn, statement),
         {:ok, [result]} <-
           execute_device_exists_query(conn, prepared, params,
             consistency: :quorum,
             uuid_format: :binary
           ) do
      {:ok, device_exists_result_to_boolean(result)}
    end
  end

  defp device_exists_result_to_boolean(%{count: 1}), do: true
  defp device_exists_result_to_boolean(_), do: false

  defp execute_device_exists_query(conn, prepared, params, opts) do
    case Xandra.execute(conn, prepared, params, opts) do
      {:ok, %Xandra.Page{} = page} ->
        {:ok, Enum.to_list(page)}

      {:error, %Xandra.ConnectionError{}} ->
        _ =
          Logger.warn(
            "Cannot check if device exists, connection error",
            tag: "check_device_exists_connection_error"
          )

        {:error, :database_connection_error}

      {:error, %Xandra.Error{} = error} ->
        _ =
          Logger.warn(
            "Cannot check if device exists, reason #{error.message}",
            tag: "check_device_exists_error"
          )

        {:error, error.reason}
    end
  end

  def insert_device_into_deletion_in_progress(realm_name, device_id) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_insert_device_into_deletion_in_progress(&1, realm_name, device_id)
    )
  end

  defp do_insert_device_into_deletion_in_progress(conn, realm_name, device_id) do
    # TODO: validate realm name
    statement = """
    INSERT INTO #{realm_name}.deletion_in_progress
    (device_id, vmq_ack, dup_start_ack, dup_end_ack)
    VALUES (:device_id, false, false, false)
    """

    params = %{device_id: device_id}

    with {:ok, prepared} <- Xandra.prepare(conn, statement) do
      case Xandra.execute(conn, prepared, params,
             consistency: :quorum,
             uuid_format: :binary
           ) do
        {:ok, result} ->
          {:ok, result}

        {:error, %Xandra.ConnectionError{}} ->
          _ =
            Logger.warn(
              "Cannot insert device #{inspect(device_id)} into deleted, connection error",
              tag: "insert_device_into_deleted_connection_error"
            )

          {:error, :database_connection_error}

        {:error, %Xandra.Error{} = error} ->
          _ =
            Logger.warn(
              "Cannot insert device #{inspect(device_id)} into deleted, reason #{error.message}",
              tag: "insert_device_into_deleted_error"
            )

          {:error, error.reason}
      end
    end
  end

  # TODO maybe move to AstarteDataAccess
  def retrieve_device_introspection_map!(realm_name, device_id) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_retrieve_introspection_map!(&1, realm_name, device_id)
    )
  end

  defp do_retrieve_introspection_map!(conn, realm_name, device_id) do
    # TODO: validate realm name
    statement = """
    SELECT introspection
    FROM #{realm_name}.devices
    WHERE device_id=:device_id
    """

    params = %{device_id: device_id}
    prepared = Xandra.prepare!(conn, statement)

    [%{introspection: introspection_map}] =
      Xandra.execute!(conn, prepared, params, consistency: :quorum, uuid_format: :binary)
      |> Enum.to_list()

    # Introspection might be still empty: handle the nil case
    introspection_map || %{}
  end

  def retrieve_interface_descriptor!(
        realm_name,
        interface_name,
        interface_major
      ) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_retrieve_interface_descriptor!(
        &1,
        realm_name,
        interface_name,
        interface_major
      )
    )
  end

  defp do_retrieve_interface_descriptor!(
         conn,
         realm_name,
         interface_name,
         interface_major
       ) do
    # TODO: validate realm name
    statement = """
    SELECT *
    FROM #{realm_name}.interfaces
    WHERE name=:name AND major_version=:major_version
    """

    params = %{name: interface_name, major_version: interface_major}

    prepared = Xandra.prepare!(conn, statement)

    Xandra.execute!(conn, prepared, params, consistency: :quorum)
    |> Enum.to_list()
    # If we're looking for a descriptor of an interface of known name and major, we're fairly sure the result is unique
    |> hd()
    |> Astarte.Core.InterfaceDescriptor.from_db_result!()
  end

  def retrieve_individual_datastreams_keys!(realm_name, device_id) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_retrieve_individual_datastreams_keys!(&1, realm_name, device_id)
    )
  end

  defp do_retrieve_individual_datastreams_keys!(conn, realm_name, device_id) do
    # TODO: validate realm name
    statement = """
    SELECT DISTINCT device_id, interface_id, endpoint_id, path
    FROM #{realm_name}.individual_datastreams
    WHERE device_id=:device_id ALLOW FILTERING
    """

    params = %{device_id: device_id}

    prepared = Xandra.prepare!(conn, statement)
    Xandra.execute!(conn, prepared, params, uuid_format: :binary) |> Enum.to_list()
  end

  def delete_individual_datastream_values!(
        realm_name,
        device_id,
        interface_id,
        endpoint_id,
        path
      ) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_delete_individual_datastream_values!(
        &1,
        realm_name,
        device_id,
        interface_id,
        endpoint_id,
        path
      )
    )
  end

  defp do_delete_individual_datastream_values!(
         conn,
         realm_name,
         device_id,
         interface_id,
         endpoint_id,
         path
       ) do
    # TODO: validate realm name
    statement = """
    DELETE FROM #{realm_name}.individual_datastreams
    WHERE device_id=:device_id AND interface_id=:interface_id
    AND endpoint_id=:endpoint_id AND path=:path
    """

    params = %{
      device_id: device_id,
      interface_id: interface_id,
      endpoint_id: endpoint_id,
      path: path
    }

    prepared = Xandra.prepare!(conn, statement)

    Xandra.execute!(conn, prepared, params,
      consistency: :local_quorum,
      uuid_format: :binary
    )
  end

  def retrieve_individual_properties_keys!(realm_name, device_id) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_retrieve_individual_properties_keys!(&1, realm_name, device_id)
    )
  end

  defp do_retrieve_individual_properties_keys!(conn, realm_name, device_id) do
    # TODO: validate realm name
    statement = """
    SELECT DISTINCT device_id, interface_id
    FROM #{realm_name}.individual_properties
    WHERE device_id=:device_id ALLOW FILTERING
    """

    params = %{device_id: device_id}

    prepared = Xandra.prepare!(conn, statement)
    Xandra.execute!(conn, prepared, params, uuid_format: :binary) |> Enum.to_list()
  end

  def delete_individual_properties_values!(realm_name, device_id, interface_id) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_delete_individual_properties_values!(&1, realm_name, device_id, interface_id)
    )
  end

  defp do_delete_individual_properties_values!(
         conn,
         realm_name,
         device_id,
         interface_id
       ) do
    # TODO: validate realm name
    statement = """
    DELETE FROM #{realm_name}.individual_properties
    WHERE device_id=:device_id AND interface_id=:interface_id
    """

    params = %{
      device_id: device_id,
      interface_id: interface_id
    }

    prepared = Xandra.prepare!(conn, statement)

    Xandra.execute!(conn, prepared, params,
      consistency: :local_quorum,
      uuid_format: :binary
    )
  end

  def retrieve_object_datastream_keys!(realm_name, device_id, table_name) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_retrieve_object_datastream_keys!(&1, realm_name, device_id, table_name)
    )
  end

  defp do_retrieve_object_datastream_keys!(
         conn,
         realm_name,
         device_id,
         table_name
       ) do
    # TODO: validate realm name
    statement = """
    SELECT DISTINCT device_id, path
    FROM #{realm_name}.#{table_name}
    WHERE device_id=:device_id ALLOW FILTERING
    """

    params = %{device_id: device_id}

    prepared = Xandra.prepare!(conn, statement)
    Xandra.execute!(conn, prepared, params, uuid_format: :binary) |> Enum.to_list()
  end

  def delete_object_datastream_values!(realm_name, device_id, path, table_name) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_delete_object_datastream_values!(&1, realm_name, device_id, path, table_name)
    )
  end

  defp do_delete_object_datastream_values!(
         conn,
         realm_name,
         device_id,
         path,
         table_name
       ) do
    # TODO: validate realm name
    statement = """
    DELETE FROM #{realm_name}.#{table_name}
    WHERE device_id=:device_id AND path=:path
    """

    params = %{
      device_id: device_id,
      path: path
    }

    prepared = Xandra.prepare!(conn, statement)

    Xandra.execute!(conn, prepared, params,
      consistency: :local_quorum,
      uuid_format: :binary
    )
  end

  def retrieve_aliases!(realm_name, device_id) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_retrieve_aliases!(&1, realm_name, device_id)
    )
  end

  defp do_retrieve_aliases!(conn, realm_name, device_id) do
    # TODO: validate realm name
    statement = """
    SELECT object_name
    FROM #{realm_name}.names
    WHERE object_uuid =:device_id ALLOW FILTERING
    """

    params = %{device_id: device_id}

    prepared = Xandra.prepare!(conn, statement)
    Xandra.execute!(conn, prepared, params, uuid_format: :binary) |> Enum.to_list()
  end

  def delete_alias_values!(realm_name, device_alias) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_delete_alias_values!(&1, realm_name, device_alias)
    )
  end

  defp do_delete_alias_values!(conn, realm_name, device_alias) do
    # TODO: validate realm name
    statement = """
    DELETE FROM #{realm_name}.names
    WHERE object_name = :device_alias
    """

    params = %{device_alias: device_alias}

    prepared = Xandra.prepare!(conn, statement)

    Xandra.execute!(conn, prepared, params,
      consistency: :local_quorum,
      uuid_format: :binary
    )
  end

  def retrieve_groups_keys!(realm_name, device_id) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_retrieve_groups_keys!(&1, realm_name, device_id)
    )
  end

  defp do_retrieve_groups_keys!(conn, realm_name, device_id) do
    # TODO: validate realm name
    statement = """
    SELECT group_name, insertion_uuid, device_id
    FROM #{realm_name}.grouped_devices
    WHERE device_id=:device_id ALLOW FILTERING
    """

    params = %{device_id: device_id}

    prepared = Xandra.prepare!(conn, statement)

    Xandra.execute!(conn, prepared, params, uuid_format: :binary, timeuuid_format: :binary)
    |> Enum.to_list()
  end

  def delete_group_values!(realm_name, device_id, group_name, insertion_uuid) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_delete_group_values!(&1, realm_name, device_id, group_name, insertion_uuid)
    )
  end

  defp do_delete_group_values!(
         conn,
         realm_name,
         device_id,
         group_name,
         insertion_uuid
       ) do
    # TODO: validate realm name
    statement = """
    DELETE FROM #{realm_name}.grouped_devices
    WHERE group_name = :group_name AND insertion_uuid = :insertion_uuid AND device_id = :device_id
    """

    params = %{
      group_name: group_name,
      insertion_uuid: insertion_uuid,
      device_id: device_id
    }

    prepared = Xandra.prepare!(conn, statement)

    Xandra.execute!(conn, prepared, params,
      consistency: :local_quorum,
      uuid_format: :binary,
      timeuuid_format: :binary
    )
  end

  def retrieve_kv_store_entries!(realm_name, device_id) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_retrieve_kv_store_entries!(&1, realm_name, device_id)
    )
  end

  defp do_retrieve_kv_store_entries!(conn, realm_name, encoded_device_id) do
    # TODO: validate realm name
    statement = """
    SELECT group, key
    FROM #{realm_name}.kv_store
    WHERE key=:key ALLOW FILTERING
    """

    params = %{key: encoded_device_id}

    prepared = Xandra.prepare!(conn, statement)
    Xandra.execute!(conn, prepared, params, uuid_format: :binary) |> Enum.to_list()
  end

  def delete_kv_store_entry!(realm_name, group, key) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_delete_kv_store_entry!(&1, realm_name, group, key)
    )
  end

  defp do_delete_kv_store_entry!(conn, realm_name, group, key) do
    # TODO: validate realm name
    statement = """
    DELETE FROM #{realm_name}.kv_store
    WHERE group = :group AND key = :key
    """

    params = %{group: group, key: key}

    prepared = Xandra.prepare!(conn, statement)

    Xandra.execute!(conn, prepared, params,
      consistency: :local_quorum,
      uuid_format: :binary
    )
  end

  def delete_device!(realm_name, device_id) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_delete_device!(&1, realm_name, device_id)
    )
  end

  defp do_delete_device!(conn, realm_name, device_id) do
    # TODO: validate realm name
    statement = """
    DELETE FROM #{realm_name}.devices
    WHERE device_id = :device_id
    """

    params = %{device_id: device_id}

    prepared = Xandra.prepare!(conn, statement)

    Xandra.execute!(conn, prepared, params,
      consistency: :local_quorum,
      uuid_format: :binary
    )
  end

  def remove_device_from_deletion_in_progress!(realm_name, device_id) do
    Xandra.Cluster.run(
      :xandra_device_deletion,
      &do_remove_device_from_deletion_in_progress!(&1, realm_name, device_id)
    )
  end

  defp do_remove_device_from_deletion_in_progress!(conn, realm_name, device_id) do
    # TODO: validate realm name
    statement = """
    DELETE FROM #{realm_name}.deletion_in_progress
    WHERE device_id = :device_id
    """

    params = %{device_id: device_id}

    prepared = Xandra.prepare!(conn, statement)

    Xandra.execute!(conn, prepared, params,
      consistency: :local_quorum,
      uuid_format: :binary
    )
  end

  def retrieve_realms!() do
    statement = """
    SELECT *
    FROM astarte.realms
    """

    realms =
      Xandra.Cluster.run(
        :xandra,
        &Xandra.execute!(&1, statement, %{}, consistency: :local_quorum)
      )

    Enum.to_list(realms)
  end

  def retrieve_devices_to_delete!(realm_name) do
    Xandra.Cluster.run(:xandra_device_deletion, &do_retrieve_devices_to_delete!(&1, realm_name))
  end

  defp do_retrieve_devices_to_delete!(conn, realm_name) do
    # TODO: validate realm name
    statement = """
    SELECT *
    FROM #{realm_name}.deletion_in_progress
    """

    Xandra.execute!(conn, statement, %{},
      consistency: :local_quorum,
      uuid_format: :binary
    )
    |> Enum.to_list()
    |> Enum.filter(fn %{vmq_ack: vmq_ack, dup_start_ack: dup_start_ack, dup_end_ack: dup_end_ack} ->
      vmq_ack and dup_start_ack and dup_end_ack
    end)
  end

  def get_device_registration_limit(realm_name) do
    Xandra.Cluster.run(:xandra, &do_get_device_registration_limit(&1, realm_name))
  end

  defp do_get_device_registration_limit(conn, realm_name) do
    query = """
    SELECT device_registration_limit
    FROM astarte.realms
    WHERE realm_name = :realm_name
    """

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, page} <-
           Xandra.execute(conn, prepared, %{realm_name: realm_name}, consistency: :one) do
      case Enum.to_list(page) do
        [%{device_registration_limit: value}] -> {:ok, value}
        [] -> {:error, :realm_not_found}
      end
    else
      {:error, %Xandra.ConnectionError{} = error} ->
        _ =
          Logger.warn(
            "Database connection error: #{Exception.message(error)}",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}

      {:error, %Xandra.Error{} = error} ->
        _ =
          Logger.warn(
            "Database error: #{Exception.message(error)}",
            tag: "database_error"
          )

        {:error, :database_error}
    end
  end
end
