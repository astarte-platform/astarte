#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
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
  alias Astarte.Core.Mapping.Reliability
  alias Astarte.Core.Mapping.Retention
  alias Astarte.Core.Mapping.ValueType
  alias Astarte.Core.StorageType
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.Core.Triggers.Trigger
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

  @query_interface_versions """
    SELECT major_version, minor_version FROM interfaces WHERE name=:interface_name;
  """

  @query_interface_available_major """
    SELECT COUNT(*) FROM interfaces WHERE name=:interface_name AND major_version=:interface_major;
  """

  @query_interfaces """
    SELECT DISTINCT name FROM interfaces;
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

    {value_timestamp, key_timestamp} =
      if interface_descriptor.explicit_timestamp do
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
        Logger.warn("Failed batch upsert due to database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("Failed batch upsert due to database error: #{inspect(reason)}")
        {:error, :database_error}
    end
  end

  defp execute_batch(client, queries) do
    Logger.debug("Trying to run #{inspect(length(queries))} queries, not running in batched mode")

    Enum.reduce_while(queries, :ok, fn query, _acc ->
      with {:ok, _result} <- DatabaseQuery.call(client, query) do
        {:cont, :ok}
      else
        %{acc: _, msg: err_msg} ->
          Logger.warn("Failed due to database error: #{err_msg}, changed will not be undone!")

          {:halt, {:error, :database_error}}

        {:error, err} ->
          Logger.warn(
            "Failed due to database error: #{inspect(err)}, changes will not be undone!"
          )

          {:halt, {:error, :database_error}}
      end
    end)
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
        Logger.debug("install_new_interface: creating new table.")
        DatabaseQuery.call(client, create_table_statement)
      else
        {:ok, nil}
      end

    {transitions, accepting_states} = automaton

    accepting_states =
      Enum.reduce(accepting_states, %{}, fn state, new_states ->
        {state_index, endpoint} = state

        Map.put(new_states, state_index, CQLUtils.endpoint_id(interface_name, major, endpoint))
      end)

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
      |> DatabaseQuery.put(:automaton_transitions, :erlang.term_to_binary(transitions))
      |> DatabaseQuery.put(:automaton_accepting_states, :erlang.term_to_binary(accepting_states))
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
      interface_type, endpoint, value_type, reliability, retention, expiry, allow_unset,
      description, doc
    )
    VALUES (
      :interface_id, :endpoint_id, :interface_name, :interface_major_version, :interface_minor_version,
      :interface_type, :endpoint, :value_type, :reliability, :retention, :expiry, :allow_unset,
      :description, :doc
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
    |> DatabaseQuery.put(:expiry, mapping.expiry)
    |> DatabaseQuery.put(:allow_unset, mapping.allow_unset)
    |> DatabaseQuery.put(:description, mapping.description)
    |> DatabaseQuery.put(:doc, mapping.doc)
    |> DatabaseQuery.consistency(:each_quorum)
  end

  def update_interface(client, interface_descriptor, new_mappings, automaton, description, doc) do
    %InterfaceDescriptor{
      name: interface_name,
      major_version: major,
      minor_version: minor,
      type: interface_type,
      interface_id: interface_id
    } = interface_descriptor

    {automaton_transitions, automaton_accepting_states} = automaton
    automaton_accepting_states_bin = :erlang.term_to_binary(automaton_accepting_states)
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

  def update_interface_storage(
        client,
        %InterfaceDescriptor{storage_type: :one_object_datastream_dbtable, storage: table_name} =
          _interface_descriptor,
        new_mappings
      ) do
    add_cols = create_one_object_columns_for_mappings(new_mappings)

    Logger.debug("interface update: going to add #{inspect(add_cols)} to #{table_name}.")

    update_storage_statement = """
    ALTER TABLE #{table_name}
    ADD (#{add_cols})
    """

    with {:ok, %SchemaChanged{change_type: :updated} = _result} <-
           DatabaseQuery.call(client, update_storage_statement) do
      :ok
    else
      %{acc: _, msg: error_message} ->
        Logger.warn("update_interface_storage: database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("update_interface_storage: database error: #{inspect(reason)}")
        {:error, :database_error}
    end
  end

  def update_interface_storage(_client, _interface_descriptor, _new_mappings) do
    :ok
  end

  def delete_interface(client, interface_name, interface_major_version) do
    Logger.info("delete interface: #{interface_name}")

    delete_endpoints_statement = "DELETE FROM endpoints WHERE interface_id=:interface_id"

    interface_id = CQLUtils.interface_id(interface_name, interface_major_version)

    delete_endpoints =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_endpoints_statement)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.consistency(:each_quorum)

    delete_interface_statement = "DELETE FROM interfaces WHERE name=:name"

    delete_interface =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(delete_interface_statement)
      |> DatabaseQuery.put(:name, interface_name)
      |> DatabaseQuery.consistency(:each_quorum)

    # TODO: use a batch here
    with {:ok, _result} <- DatabaseQuery.call(client, delete_endpoints),
         {:ok, _result} <- DatabaseQuery.call(client, delete_interface) do
      :ok
    else
      {:error, reason} ->
        Logger.error(
          "database error while deleting #{interface_name}, reason: #{inspect(reason)}"
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
      Logger.info("Deleted #{table_name} table.")
      :ok
    else
      {:error, reason} ->
        Logger.warn("Database error: #{inspect(reason)}")
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
      |> DatabaseQuery.consistency(:each_quorum)

    with {:ok, result} <- DatabaseQuery.call(client, devices_query),
         [key: _device_id] <- DatabaseResult.head(result) do
      {:ok, true}
    else
      :empty_dataset ->
        {:ok, false}

      {:error, reason} ->
        Logger.warn("is_any_device_using_interface?: database error: #{inspect(reason)}.")
        {:error, :database_error}
    end
  end

  def devices_with_data_on_interface(client, interface_name) do
    devices_statement = "SELECT key FROM kv_store WHERE group=:group_name"

    devices_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(devices_statement)
      |> DatabaseQuery.put(:group_name, "devices-with-data-on-interface-#{interface_name}-v0")
      |> DatabaseQuery.consistency(:each_quorum)

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
        Logger.warn("delete_devices_with_data_on_interface: database error: #{inspect(reason)}")
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
        Logger.warn("Database error: cannot delete values. reason: #{inspect(reason)}")
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
        Logger.warn("Database error: cannot delete path values. reason: #{inspect(reason)}")
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
      |> DatabaseQuery.consistency(:each_quorum)

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
        Logger.warn("database error while deleting all paths: #{inspect(reason)}")
        {:error, :database_error}
    end
  end

  def interface_available_versions(client, interface_name) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@query_interface_versions)
      |> DatabaseQuery.put(:interface_name, interface_name)

    DatabaseQuery.call!(client, query)
    |> Enum.to_list()
  end

  def is_interface_major_available?(client, interface_name, interface_major) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@query_interface_available_major)
      |> DatabaseQuery.put(:interface_name, interface_name)
      |> DatabaseQuery.put(:interface_major, interface_major)

    count =
      DatabaseQuery.call!(client, query)
      |> Enum.to_list()
      |> List.first()

    count != [count: 0]
  end

  def check_correct_casing(client, interface_name) do
    lowercase_interface = String.downcase(interface_name)

    all_names_statement = """
    SELECT DISTINCT name
    FROM interfaces
    """

    all_names_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(all_names_statement)
      |> DatabaseQuery.consistency(:each_quorum)

    with {:ok, result} <- DatabaseQuery.call(client, all_names_query) do
      found_name =
        Enum.find_value(result, :not_found, fn row ->
          if String.downcase(row[:name]) == lowercase_interface do
            row[:name]
          else
            false
          end
        end)

      case found_name do
        ^interface_name ->
          :ok

        :not_found ->
          :ok

        _ ->
          {:error, :invalid_name_casing}
      end
    else
      %{acc: _, msg: error_message} ->
        Logger.warn("has_correct_casing: database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("has_correct_casing: database error: #{inspect(reason)}")
        {:error, :database_error}
    end
  end

  def fetch_interface(client, interface_name, interface_major) do
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
      |> DatabaseQuery.consistency(:each_quorum)

    all_endpoints_cols_statement = """
    SELECT *
    FROM endpoints
    WHERE interface_id = :interface_id
    """

    endpoints_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(all_endpoints_cols_statement)
      |> DatabaseQuery.consistency(:each_quorum)

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
        Logger.warn("interface_source: database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("interface_source: failed, reason: #{inspect(reason)}.")
        {:error, :database_error}
    end
  end

  def get_interfaces_list(client) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(@query_interfaces)

    rows =
      DatabaseQuery.call!(client, query)
      |> Enum.to_list()

    for result <- rows do
      result[:name]
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
      |> DatabaseQuery.consistency(:each_quorum)

    with {:ok, result} <- DatabaseQuery.call(db_client, simple_triggers_query),
         [count: count] <- DatabaseResult.head(result) do
      if count != 0 do
        {:ok, true}
      else
        {:ok, false}
      end
    else
      %{acc: _, msg: error_message} ->
        Logger.warn("interface_owns_simple_triggers?: database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("interface_owns_simple_triggers?: failed with reason #{inspect(reason)}")
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
        Logger.warn("Database error: #{inspect(not_ok)}")
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
        Logger.warn("Database error: #{inspect(not_ok)}")
        {:error, :cannot_install_simple_trigger}
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
        Logger.warn("Queries.retrieve_trigger_uuid: database error: #{inspect(not_ok)}")
        {:error, :cannot_retrieve_trigger_uuid}
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
          Logger.warn("Queries.delete_trigger: database error: #{inspect(not_ok)}")
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
          Logger.warn("Queries.get_triggers_list: database error: #{inspect(not_ok)}")
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
          Logger.warn("Queries.retrieve_trigger: database error: #{inspect(not_ok)}")
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
          Logger.warn(
            "Queries.retrieve_simple_trigger: possible inconsistency found: database error: #{
              inspect(not_ok)
            }"
          )

          {:error, :cannot_retrieve_simple_trigger}
      end
    else
      :empty_dataset ->
        {:error, :simple_trigger_not_found}

      not_ok ->
        Logger.warn("Queries.retrieve_trigger: database error: #{inspect(not_ok)}")
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
          Logger.warn("Queries.delete_simple_trigger: database error: #{inspect(not_ok)}")
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
        Logger.warn(
          "Queries.retrieve_simple_trigger_astarte_ref: database error: #{inspect(not_ok)}"
        )

        {:error, :cannot_retrieve_simple_trigger}
    end
  end
end
