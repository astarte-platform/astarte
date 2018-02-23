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

  require Logger
  alias Astarte.Core.AstarteReference
  alias Astarte.Core.StorageType
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.Core.Triggers.Trigger
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult

  @insert_into_interfaces """
    INSERT INTO interfaces
      (name, major_version, minor_version, interface_id, storage_type, storage, type, quality, flags, source, automaton_transitions, automaton_accepting_states)
      VALUES (:name, :major_version, :minor_version, :interface_id, :storage_type, :storage, :type, :ownership, :aggregation, :source, :automaton_transitions, :automaton_accepting_states)
  """

  @insert_into_endpoints """
  INSERT INTO endpoints
    (interface_id, endpoint_id, interface_name, interface_major_version, interface_minor_version, interface_type, endpoint, value_type, reliabilty, retention, expiry, allow_unset)
    VALUES (:interface_id, :endpoint_id, :interface_name, :interface_major_version, :interface_minor_version, :interface_type, :endpoint, :value_type, :reliability, :retention, :expiry, :allow_unset)
  """

  # TODO: should we add reception_timestamp_submillis only to datastreams?
  @create_individual_multiinterface_table """
    CREATE TABLE IF NOT EXISTS :table_name (
      device_id uuid,
      interface_id uuid,
      endpoint_id uuid,
      path varchar,
      :value_timestamp
      reception_timestamp timestamp,
      reception_timestamp_submillis smallint,
      endpoint_tokens list<varchar>,

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

      PRIMARY KEY((device_id, interface_id), endpoint_id, path :key_timestamp)
    )
  """

  @create_interface_table_with_individual_aggregation """
    CREATE TABLE :interface_name (
      device_id uuid,
      endpoint_id uuid,
      path varchar,
      :value_timestamp
      reception_timestamp timestamp,
      endpoint_tokens list<varchar>,
      :columns,
      PRIMARY KEY(device_id, endpoint_id, path :key_timestamp)
    )
  """

  @create_interface_table_with_object_aggregation """
    CREATE TABLE :interface_name (
      device_id uuid,
      :value_timestamp,
      reception_timestamp timestamp,
      reception_timestamp_submillis smallint,
      :columns,

      PRIMARY KEY(device_id, :key_timestamp reception_timestamp, reception_timestamp_submillis)
    )
  """

  @delete_interface_endpoints """
     DELETE FROM endpoints WHERE interface_id=:interface_id;
  """

  @delete_interface_from_interfaces """
     DELETE FROM interfaces WHERE name=:name;
  """

  # TODO: disable DROP TABLE
  #  @drop_interface_table """
  #   DROP TABLE :table_name;
  #"""

  @query_interface_versions """
    SELECT major_version, minor_version FROM interfaces WHERE name=:interface_name;
  """

  @query_interface_available_major """
    SELECT COUNT(*) FROM interfaces WHERE name=:interface_name AND major_version=:interface_major;
  """

  @query_interface_source """
    SELECT source FROM interfaces WHERE name=:interface_name AND major_version=:interface_major;
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

  defp create_interface_table(:individual, :multi, interface_descriptor, _mappings) do
    {table_type, suffix, value_timestamp, key_timestamp} =
      case interface_descriptor.type do
        :datastream ->
          {:multi_interface_individual_datastream_dbtable, "datastream", "value_timestamp timestamp,", ", value_timestamp, reception_timestamp"}

        :properties ->
          {:multi_interface_individual_properties_dbtable, "property", "", ""}
      end

    table_name = "individual_#{suffix}"

    create_table_statement = @create_individual_multiinterface_table
      |> String.replace(":table_name", table_name)
      |> String.replace(":value_timestamp", value_timestamp)
      |> String.replace(":key_timestamp", key_timestamp)

    {table_type, table_name, create_table_statement}
  end

  defp create_interface_table(:individual, :one, interface_descriptor, mappings) do
    table_name = Astarte.Core.CQLUtils.interface_name_to_table_name(interface_descriptor.name, interface_descriptor.major_version)

    mappings_cql = for mapping <- mappings do
        "#{Astarte.Core.CQLUtils.type_to_db_column_name(mapping.value_type)} #{Astarte.Core.CQLUtils.mapping_value_type_to_db_type(mapping.value_type)}"
    end

    columns = mappings_cql
      |> Enum.uniq
      |> Enum.sort
      |> Enum.join(~s(,\n))

    {table_type, value_timestamp, key_timestamp} =
      case interface_descriptor.type do
        :datastream ->
          {:one_individual_datastream_dbtable, "value_timestamp timestamp, ", ", value_timestamp, reception_timestamp, reception_timestamp_submillis"}

        :properties ->
          {:one_individual_properties_dbtable, "", ""}
      end

    create_table_statement = @create_interface_table_with_individual_aggregation
    |> String.replace(":interface_name", table_name)
    |> String.replace(":value_timestamp", value_timestamp)
    |> String.replace(":columns", columns)
    |> String.replace(":key_timestamp", key_timestamp)

    {table_type, table_name, create_table_statement}
  end

  defp create_interface_table(:object, :one, interface_descriptor, mappings) do
    table_name = Astarte.Core.CQLUtils.interface_name_to_table_name(interface_descriptor.name, interface_descriptor.major_version)

    mappings_cql = for mapping <- mappings do
      "#{Astarte.Core.CQLUtils.endpoint_to_db_column_name(mapping.endpoint)} #{Astarte.Core.CQLUtils.mapping_value_type_to_db_type(mapping.value_type)}"
    end

    columns = mappings_cql
      |> Enum.join(~s(,\n))

    {value_timestamp, key_timestamp} = if interface_descriptor.explicit_timestamp do
      {"value_timestamp timestamp,", "value_timestamp,"}
    else
      {"", ""}
    end

    create_table_statement = @create_interface_table_with_object_aggregation
      |> String.replace(":interface_name", table_name)
      |> String.replace(":value_timestamp", value_timestamp)
      |> String.replace(":columns", columns)
      |> String.replace(":key_timestamp", key_timestamp)

    {:one_object_datastream_dbtable, table_name, create_table_statement}
  end

  def install_new_interface(client, interface_document, automaton) do
    table_type = if interface_document.descriptor.aggregation == :individual do
      :multi
    else
      :one
    end

    {storage_type, table_name, create_table_statement} = create_interface_table(interface_document.descriptor.aggregation, table_type, interface_document.descriptor, interface_document.mappings)
    {:ok, _} = DatabaseQuery.call(client, create_table_statement)

    interface_id = Astarte.Core.CQLUtils.interface_id(interface_document.descriptor.name, interface_document.descriptor.major_version)

    {transitions, accepting_states} = automaton

    accepting_states = Enum.reduce(accepting_states, %{}, fn(state, new_states) ->
      {state_index, endpoint} = state
      Map.put(new_states, state_index, Astarte.Core.CQLUtils.endpoint_id(interface_document.descriptor.name, interface_document.descriptor.major_version, endpoint))
    end)

    query = DatabaseQuery.new
      |> DatabaseQuery.statement(@insert_into_interfaces)
      |> DatabaseQuery.put(:name, interface_document.descriptor.name)
      |> DatabaseQuery.put(:major_version, interface_document.descriptor.major_version)
      |> DatabaseQuery.put(:minor_version, interface_document.descriptor.minor_version)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.put(:storage_type, StorageType.to_int(storage_type))
      |> DatabaseQuery.put(:storage, table_name)
      |> DatabaseQuery.put(:type, Astarte.Core.Interface.Type.to_int(interface_document.descriptor.type))
      |> DatabaseQuery.put(:ownership, Astarte.Core.Interface.Ownership.to_int(interface_document.descriptor.ownership))
      |> DatabaseQuery.put(:aggregation, Astarte.Core.Interface.Aggregation.to_int(interface_document.descriptor.aggregation))
      |> DatabaseQuery.put(:source, interface_document.source)
      |> DatabaseQuery.put(:automaton_transitions, :erlang.term_to_binary(transitions))
      |> DatabaseQuery.put(:automaton_accepting_states, :erlang.term_to_binary(accepting_states))
    {:ok, _} = DatabaseQuery.call(client, query)

    base_query = DatabaseQuery.new
      |> DatabaseQuery.statement(@insert_into_endpoints)
      |> DatabaseQuery.put(:interface_name, interface_document.descriptor.name)
      |> DatabaseQuery.put(:interface_major_version, interface_document.descriptor.major_version)
      |> DatabaseQuery.put(:interface_minor_version, interface_document.descriptor.minor_version)
      |> DatabaseQuery.put(:interface_type, Astarte.Core.Interface.Type.to_int(interface_document.descriptor.type))

    for mapping <- interface_document.mappings do
      query = base_query
        |> DatabaseQuery.put(:interface_id, interface_id)
        |> DatabaseQuery.put(:endpoint_id, Astarte.Core.CQLUtils.endpoint_id(interface_document.descriptor.name, interface_document.descriptor.major_version, mapping.endpoint))
        |> DatabaseQuery.put(:endpoint, mapping.endpoint)
        |> DatabaseQuery.put(:value_type, Astarte.Core.Mapping.ValueType.to_int(mapping.value_type))
        |> DatabaseQuery.put(:reliability, Astarte.Core.Mapping.Reliability.to_int(mapping.reliability))
        |> DatabaseQuery.put(:retention, Astarte.Core.Mapping.Retention.to_int(mapping.retention))
        |> DatabaseQuery.put(:expiry, mapping.expiry)
        |> DatabaseQuery.put(:allow_unset, mapping.allow_unset)
      {:ok, _} = DatabaseQuery.call(client, query)
    end

    :ok
  end

  def update_interface(client, interface_document) do
    Logger.warn "update_interface: #{inspect interface_document}"
    Logger.warn "client: #{inspect client}"

    {:error, :not_implemented}
  end

  def delete_interface(client, interface_name, interface_major_version) do
    if interface_major_version != 0 do
      {:error, :forbidden}

    else
      Logger.info "delete interface: #{interface_name}"

      interface_id = Astarte.Core.CQLUtils.interface_id(interface_name, interface_major_version)

      query = DatabaseQuery.new
        |> DatabaseQuery.statement(@delete_interface_from_interfaces)
        |> DatabaseQuery.put(:name, interface_name)
      DatabaseQuery.call!(client, query)

      delete_query = DatabaseQuery.new
        |> DatabaseQuery.statement(@delete_interface_endpoints)
        |> DatabaseQuery.put(:interface_id, interface_id)
      DatabaseQuery.call!(client, delete_query)

      #TODO: no need to delete a table for the multi interface approach
      #drop_table_statement = @drop_interface_table
      #  |> String.replace(":table_name", Astarte.Core.CQLUtils.interface_name_to_table_name(interface_name, 0))
      #DatabaseQuery.call!(client, drop_table_statement)

      :ok
    end
  end

  def interface_available_versions(client, interface_name) do
    query = DatabaseQuery.new
      |> DatabaseQuery.statement(@query_interface_versions)
      |> DatabaseQuery.put(:interface_name, interface_name)

    DatabaseQuery.call!(client, query)
    |> Enum.to_list
  end

  def is_interface_major_available?(client, interface_name, interface_major) do
    query = DatabaseQuery.new
      |> DatabaseQuery.statement(@query_interface_available_major)
      |> DatabaseQuery.put(:interface_name, interface_name)
      |> DatabaseQuery.put(:interface_major, interface_major)
    count = DatabaseQuery.call!(client, query)
      |> Enum.to_list
      |> List.first

    count != [count: 0]
  end

  def interface_source(client, interface_name, interface_major) do
    query = DatabaseQuery.new
      |> DatabaseQuery.statement(@query_interface_source)
      |> DatabaseQuery.put(:interface_name, interface_name)
      |> DatabaseQuery.put(:interface_major, interface_major)

    result_row = DatabaseQuery.call!(client, query)
      |> Enum.to_list
      |> List.first

    if result_row != nil do
      {:ok, result_row[:source]}
    else
      {:error, :interface_not_found}
    end
  end

  def get_interfaces_list(client) do
    query = DatabaseQuery.new
      |> DatabaseQuery.statement(@query_interfaces)

    rows = DatabaseQuery.call!(client, query)
      |> Enum.to_list

    for result <- rows do
      result[:name]
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

  def install_simple_trigger(client, object_id, object_type, parent_trigger_id, simple_trigger_id, simple_trigger, trigger_target) do
    insert_simple_trigger_statement =
      """
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

    astarte_ref =
      %AstarteReference{
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
    trigger_uuid_query_statement = "SELECT value FROM kv_store WHERE group='triggers-by-name' AND key=:trigger_name;"

    trigger_uuid_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(trigger_uuid_query_statement)
      |> DatabaseQuery.put(:trigger_name, trigger_name)

    with {:ok, result} <- DatabaseQuery.call(client, trigger_uuid_query),
         ["value": trigger_uuid] <- DatabaseResult.head(result) do
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
      delete_trigger_by_name_statement = "DELETE FROM kv_store WHERE group='triggers-by-name' AND key=:trigger_name;"

      delete_trigger_by_name_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(delete_trigger_by_name_statement)
        |> DatabaseQuery.put(:trigger_name, trigger_name)

      delete_trigger_statement = "DELETE FROM kv_store WHERE group='triggers' AND key=:trigger_uuid;"

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
      retrieve_trigger_statement = "SELECT value FROM kv_store WHERE group='triggers' AND key=:trigger_uuid;"

      retrieve_trigger_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(retrieve_trigger_statement)
        |> DatabaseQuery.put(:trigger_uuid, trigger_uuid)

      with {:ok, result} <- DatabaseQuery.call(client, retrieve_trigger_query),
           [value: trigger_data] <- DatabaseResult.head(result) do
        Trigger.decode(trigger_data)
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
  def retrieve_simple_trigger(client, parent_trigger_uuid, simple_trigger_uuid) do
    retrieve_astarte_ref_statement =
      "SELECT value FROM kv_store WHERE group='simple-triggers-by-uuid' AND key=:simple_trigger_uuid;"

    retrieve_astarte_ref_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(retrieve_astarte_ref_statement)
      |> DatabaseQuery.put(:simple_trigger_uuid, :uuid.uuid_to_string(simple_trigger_uuid))

    with {:ok, result} <- DatabaseQuery.call(client, retrieve_astarte_ref_query),
         [value: astarte_ref_blob] <- DatabaseResult.head(result),
         %{object_uuid: object_id, object_type: object_type} <- AstarteReference.decode(astarte_ref_blob) do

      retrieve_simple_trigger_statement =
        """
        SELECT trigger_data, trigger_target
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
           [trigger_data: trigger_data, trigger_target: trigger_target_data] <- DatabaseResult.head(result) do

        {
          :ok,
          %{
            simple_trigger: SimpleTriggerContainer.decode(trigger_data),
            trigger_target: TriggerTargetContainer.decode(trigger_target_data)
          }
        }
      else
        not_ok ->
          Logger.warn("Queries.retrieve_simple_trigger: possible inconsistency found: database error: #{inspect(not_ok)}")
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

end
