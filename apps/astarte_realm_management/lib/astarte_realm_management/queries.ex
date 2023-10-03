#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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
  alias Astarte.DataAccess.Xandra.Utils

  @max_batch_queries 32

  @insert_into_interfaces """
    INSERT INTO :realm_name.interfaces
      (name, major_version, minor_version, interface_id, storage_type, storage, type, ownership, aggregation, automaton_transitions, automaton_accepting_states, description, doc)
      VALUES (:name, :major_version, :minor_version, :interface_id, :storage_type, :storage, :type, :ownership, :aggregation, :automaton_transitions, :automaton_accepting_states, :description, :doc)
  """

  @create_datastream_individual_multiinterface_table """
    CREATE TABLE IF NOT EXISTS :realm_name.individual_datastreams (
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
    CREATE TABLE :realm_name.:interface_name (
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
    FROM :realm_name.kv_store
    WHERE group='auth' AND key='jwt_public_key_pem';
  """

  @query_insert_jwt_public_key_pem """
  INSERT INTO :realm_name.kv_store (group, key, value)
  VALUES ('auth', 'jwt_public_key_pem', varcharAsBlob(:pem));
  """

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

    with {:ok, _result} <- execute_query(schema_statement, %{}, consistency: consistency),
         {:ok, _result} <- execute_query(realms_statement, %{}, consistency: consistency) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.warn("Health is not good, reason: #{inspect(reason)}.", tag: "health_check_bad")

        {:error, :health_check_bad}
    end
  end

  def install_new_interface(realm_name, interface_document, automaton) do
    with true <- verify_realm_ok(realm_name) do
      do_install_new_interface(realm_name, interface_document, automaton)
    end
  end

  defp do_install_new_interface(realm_name, interface_document, automaton) do
    {storage_type, table_name} = ensure_interface_table(realm_name, interface_document)

    insert_endpoints_query_list =
      build_insert_endpoints_query_list(realm_name, interface_document)

    insert_interface_query =
      build_insert_interface_query(
        realm_name,
        interface_document,
        automaton,
        table_name,
        storage_type
      )

    batch = [insert_interface_query | insert_endpoints_query_list]

    execute_batch(batch, consistency: :each_quorum)
  end

  defp ensure_interface_table(realm_name, interface_document) do
    interface_descriptor = InterfaceDescriptor.from_interface(interface_document)
    %InterfaceDescriptor{aggregation: aggregation} = interface_descriptor

    table_type =
      if aggregation == :individual do
        :multi
      else
        :one
      end

    {storage_type, table_name, create_table_statement} =
      create_interface_table(
        realm_name,
        aggregation,
        table_type,
        interface_descriptor,
        interface_document.mappings
      )

    {:ok, _result} = do_create_interface_table(create_table_statement)
    {storage_type, table_name}
  end

  defp create_one_object_columns_for_mappings(mappings) do
    for %Mapping{endpoint: endpoint, value_type: value_type} <- mappings do
      column_name = CQLUtils.endpoint_to_db_column_name(endpoint)
      cql_type = CQLUtils.mapping_value_type_to_db_type(value_type)
      "#{column_name} #{cql_type}"
    end
    |> Enum.join(~s(,\n))
  end

  defp create_interface_table(
         _realm_name,
         :individual,
         :multi,
         %InterfaceDescriptor{type: :properties},
         _mappings
       ) do
    {:multi_interface_individual_properties_dbtable, "individual_properties", ""}
  end

  defp create_interface_table(
         realm_name,
         :individual,
         :multi,
         %InterfaceDescriptor{type: :datastream},
         _mappings
       ) do
    create_table_statement =
      @create_datastream_individual_multiinterface_table
      |> String.replace(":realm_name", realm_name)

    {:multi_interface_individual_datastream_dbtable, "individual_datastreams",
     create_table_statement}
  end

  defp create_interface_table(realm_name, :object, :one, interface_descriptor, mappings) do
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
      |> String.replace(":realm_name", realm_name)
      |> String.replace(":interface_name", table_name)
      |> String.replace(":value_timestamp", value_timestamp)
      |> String.replace(":columns", columns)
      |> String.replace(":key_timestamp", key_timestamp)

    {:one_object_datastream_dbtable, table_name, create_table_statement}
  end

  defp do_create_interface_table(""), do: {:ok, nil}

  defp do_create_interface_table(create_table_statement) do
    _ = Logger.info("Creating new interface table.", tag: "create_interface_table")

    Xandra.Cluster.run(:xandra, fn conn ->
      CSystem.run_with_schema_agreement(conn, fn ->
        # TODO: check consistency
        case execute_query(conn, create_table_statement, %{}, []) do
          {:ok, result} ->
            {:ok, result}

          {:error, reason} ->
            _ = Logger.warn("Cannot create new interface table.", tag: "db_error")

            {:error, reason}
        end
      end)
    end)
  end

  defp build_insert_endpoints_query_list(realm_name, interface_document) do
    %InterfaceDescriptor{
      interface_id: interface_id,
      name: interface_name,
      major_version: major,
      minor_version: minor,
      type: interface_type
    } = InterfaceDescriptor.from_interface(interface_document)

    Enum.map(
      interface_document.mappings,
      &build_insert_mapping_query(
        realm_name,
        interface_id,
        interface_name,
        major,
        minor,
        interface_type,
        &1
      )
    )
  end

  defp build_insert_interface_query(
         realm_name,
         interface_document,
         automaton,
         table_name,
         storage_type
       ) do
    insert_interface_statement =
      @insert_into_interfaces
      |> String.replace(":realm_name", realm_name)

    %InterfaceDescriptor{
      interface_id: interface_id,
      name: interface_name,
      major_version: major,
      minor_version: minor,
      type: interface_type,
      ownership: interface_ownership,
      aggregation: aggregation
    } = InterfaceDescriptor.from_interface(interface_document)

    %InterfaceDocument{
      description: description,
      doc: doc
    } = interface_document

    {transitions, accepting_states_no_ids} = automaton

    transitions_bin = :erlang.term_to_binary(transitions)

    accepting_states_bin =
      accepting_states_no_ids
      |> replace_automaton_acceptings_with_ids(interface_name, major)
      |> :erlang.term_to_binary()

    insert_interface_params = %{
      name: interface_name,
      major_version: major,
      minor_version: minor,
      interface_id: interface_id,
      storage_type: StorageType.to_int(storage_type),
      storage: table_name,
      type: InterfaceType.to_int(interface_type),
      ownership: Ownership.to_int(interface_ownership),
      aggregation: Aggregation.to_int(aggregation),
      automaton_transitions: transitions_bin,
      automaton_accepting_states: accepting_states_bin,
      description: description,
      doc: doc
    }

    {insert_interface_statement, insert_interface_params}
  end

  defp build_insert_mapping_query(
         realm_name,
         interface_id,
         interface_name,
         major,
         minor,
         interface_type,
         mapping
       ) do
    insert_mapping_statement = """
    INSERT INTO #{realm_name}.endpoints
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

    insert_mapping_params = %{
      interface_id: interface_id,
      endpoint_id: mapping.endpoint_id,
      interface_name: interface_name,
      interface_major_version: major,
      interface_minor_version: minor,
      interface_type: InterfaceType.to_int(interface_type),
      endpoint: mapping.endpoint,
      value_type: ValueType.to_int(mapping.value_type),
      reliability: Reliability.to_int(mapping.reliability),
      retention: Retention.to_int(mapping.retention),
      database_retention_policy:
        DatabaseRetentionPolicy.to_int(mapping.database_retention_policy),
      database_retention_ttl: mapping.database_retention_ttl,
      expiry: mapping.expiry,
      allow_unset: mapping.allow_unset,
      explicit_timestamp: mapping.explicit_timestamp,
      description: mapping.description,
      doc: mapping.doc
    }

    {insert_mapping_statement, insert_mapping_params}
  end

  # TODO: this was needed when Cassandra used to generate endpoint IDs
  # it might be a good idea to drop this and generate those IDs in A.C.Mapping.EndpointsAutomaton
  defp replace_automaton_acceptings_with_ids(accepting_states, interface_name, major) do
    Enum.reduce(accepting_states, %{}, fn state, new_states ->
      {state_index, endpoint} = state

      Map.put(new_states, state_index, CQLUtils.endpoint_id(interface_name, major, endpoint))
    end)
  end

  def update_interface(
        realm_name,
        interface_descriptor,
        new_mappings,
        automaton,
        description,
        doc
      ) do
    with true <- verify_realm_ok(realm_name) do
      do_update_interface(
        realm_name,
        interface_descriptor,
        new_mappings,
        automaton,
        description,
        doc
      )
    end
  end

  defp do_update_interface(
         realm_name,
         interface_descriptor,
         new_mappings,
         automaton,
         description,
         doc
       ) do
    update_interface_query =
      build_update_interface_query(realm_name, interface_descriptor, automaton, description, doc)

    insert_new_mappings_query_list =
      build_insert_new_mappings_query_list(realm_name, interface_descriptor, new_mappings)

    execute_batch([update_interface_query | insert_new_mappings_query_list],
      consistency: :each_quorum
    )
  end

  defp build_update_interface_query(realm_name, interface_descriptor, automaton, description, doc) do
    update_interface_statement = """
    UPDATE #{realm_name}.interfaces
    SET minor_version=:minor_version, automaton_accepting_states=:automaton_accepting_states,
      automaton_transitions = :automaton_transitions, description = :description, doc = :doc
    WHERE name=:name AND major_version=:major_version
    """

    %InterfaceDescriptor{
      name: interface_name,
      major_version: major,
      minor_version: minor
    } = interface_descriptor

    {automaton_transitions, automaton_accepting_states_no_ids} = automaton

    automaton_accepting_states_bin =
      automaton_accepting_states_no_ids
      |> replace_automaton_acceptings_with_ids(interface_name, major)
      |> :erlang.term_to_binary()

    automaton_transitions_bin = :erlang.term_to_binary(automaton_transitions)

    update_interface_params = %{
      name: interface_name,
      major_version: major,
      minor_version: minor,
      automaton_accepting_states: automaton_accepting_states_bin,
      automaton_transitions: automaton_transitions_bin,
      description: description,
      doc: doc
    }

    {update_interface_statement, update_interface_params}
  end

  defp build_insert_new_mappings_query_list(realm_name, interface_descriptor, new_mappings) do
    %InterfaceDescriptor{
      name: interface_name,
      major_version: major,
      minor_version: minor,
      type: interface_type,
      interface_id: interface_id
    } = interface_descriptor

    Enum.map(
      new_mappings,
      &build_insert_mapping_query(
        realm_name,
        interface_id,
        interface_name,
        major,
        minor,
        interface_type,
        &1
      )
    )
  end

  def update_interface_storage(
        realm_name,
        interface_descriptor,
        new_mappings
      ) do
    with true <- verify_realm_ok(realm_name) do
      do_update_interface_storage(realm_name, interface_descriptor, new_mappings)
    end
  end

  defp do_update_interface_storage(_realm_name, _interface_descriptor, []) do
    # No new mappings, nothing to do
    :ok
  end

  defp do_update_interface_storage(
         realm_name,
         %InterfaceDescriptor{storage_type: :one_object_datastream_dbtable, storage: table_name},
         new_mappings
       ) do
    add_cols = create_one_object_columns_for_mappings(new_mappings)

    _ =
      Logger.debug("Interface update: going to add #{inspect(add_cols)} to #{table_name}.",
        tag: "db_interface_add_table_cols"
      )

    update_storage_statement = """
    ALTER TABLE #{realm_name}.#{table_name}
    ADD (#{add_cols})
    """

    case execute_query(update_storage_statement) do
      # See https://hexdocs.pm/xandra/Xandra.SchemaChange.html for more
      {:ok, %Xandra.SchemaChange{effect: "UPDATED", target: "TABLE"}} ->
        :ok

      {:error, reason} ->
        _ =
          Logger.warn("Cannot update table #{realm_name}.#{table_name}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  defp do_update_interface_storage(_realm_name, _interface_descriptor, _new_mappings) do
    :ok
  end

  def delete_interface(realm_name, interface_name, interface_major_version) do
    with true <- verify_realm_ok(realm_name) do
      do_delete_interface(realm_name, interface_name, interface_major_version)
    end
  end

  defp do_delete_interface(realm_name, interface_name, interface_major_version) do
    _ =
      Logger.info("Delete interface.",
        interface: interface_name,
        interface_major: interface_major_version,
        tag: "db_delete_interface"
      )

    delete_endpoints_statement =
      "DELETE FROM #{realm_name}.endpoints WHERE interface_id=:interface_id"

    interface_id = CQLUtils.interface_id(interface_name, interface_major_version)

    delete_endpoints_params = %{interface_id: interface_id}

    delete_interface_statement =
      "DELETE FROM #{realm_name}.interfaces WHERE name=:name AND major_version=:major"

    delete_interface_params = %{
      name: interface_name,
      major: interface_major_version
    }

    batch_result =
      execute_batch(
        [
          {delete_endpoints_statement, delete_endpoints_params},
          {delete_interface_statement, delete_interface_params}
        ],
        consistency: :each_quorum
      )

    case batch_result do
      :ok ->
        :ok

      {:error, reason} ->
        _ =
          Logger.warn(
            "Cannot delete interface #{interface_name} v#{interface_major_version}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  def delete_interface_storage(
        realm_name,
        %InterfaceDescriptor{} = interface_descriptor
      ) do
    with true <- verify_realm_ok(realm_name) do
      do_delete_interface_storage(realm_name, interface_descriptor)
    end
  end

  defp do_delete_interface_storage(
         realm_name,
         %InterfaceDescriptor{
           storage_type: :one_object_datastream_dbtable,
           storage: table_name
         }
       ) do
    delete_statement = "DROP TABLE IF EXISTS #{realm_name}.#{table_name}"

    case execute_query(delete_statement, %{}) do
      {:ok, %Xandra.SchemaChange{effect: "DROPPED", target: "TABLE"}} ->
        _ =
          Logger.info("Deleted #{table_name} table on #{realm_name}.",
            tag: "db_delete_interface_table"
          )

        :ok

      {:error, reason} ->
        _ =
          Logger.warn(
            "Cannot delete interface storage for #{table_name} on #{realm_name}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  defp do_delete_interface_storage(realm_name, interface_descriptor) do
    with {:ok, result} <- devices_with_data_on_interface(realm_name, interface_descriptor.name) do
      # TODO check this (it is now a list and not a CQEx.Result)
      Enum.reduce_while(result, :ok, fn %{key: encoded_device_id}, _acc ->
        with {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
             :ok <- delete_values(realm_name, device_id, interface_descriptor) do
          {:cont, :ok}
        else
          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)
    end
  end

  def is_any_device_using_interface?(realm_name, interface_name) do
    with true <- verify_realm_ok(realm_name) do
      do_is_any_device_using_interface?(realm_name, interface_name)
    end
  end

  defp do_is_any_device_using_interface?(realm_name, interface_name) do
    devices_query_statement =
      "SELECT key FROM #{realm_name}.kv_store WHERE group=:group_name LIMIT 1"

    # TODO: validate interface name?
    devices_query_params = %{
      group_name: "devices-by-interface-#{interface_name}-v0"
    }

    case execute_query(devices_query_statement, devices_query_params, consistency: :quorum) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [%{key: _device_id}] ->
            {:ok, true}

          [] ->
            {:ok, false}
        end

      {:error, reason} ->
        _ = Logger.warn("Database error: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  defp devices_with_data_on_interface(realm_name, interface_name) do
    devices_query_statement = "SELECT key FROM #{realm_name}.kv_store WHERE group=:group_name"

    # TODO: validate interface name?
    devices_query_params = %{
      group_name: "devices-with-data-on-interface-#{interface_name}-v0"
    }

    case execute_query(devices_query_statement, devices_query_params, consistency: :quorum) do
      {:ok, %Xandra.Page{} = page} ->
        # TODO: check returned value: it is now a list and not a CQEx.Result
        {:ok, Enum.to_list(page)}

      {:error, reason} ->
        _ =
          Logger.warn(
            "Cannot get devices with data on interface #{interface_name}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  def delete_devices_with_data_on_interface(realm_name, interface_name) do
    with true <- verify_realm_ok(realm_name) do
      do_delete_devices_with_data_on_interface(realm_name, interface_name)
    end
  end

  defp do_delete_devices_with_data_on_interface(realm_name, interface_name) do
    devices_query_statement = "DELETE FROM #{realm_name}.kv_store WHERE group=:group_name"

    # TODO: validate interface name?
    devices_query_params = %{
      group_name: "devices-with-data-on-interface-#{interface_name}-v0"
    }

    case execute_query(devices_query_statement, devices_query_params, consistency: :each_quorum) do
      {:ok, %Xandra.Void{}} ->
        :ok

      {:error, reason} ->
        _ =
          Logger.warn(
            "Cannot delete devices with data on interface #{interface_name}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  defp delete_values(
         realm_name,
         device_id,
         %InterfaceDescriptor{
           interface_id: interface_id,
           storage_type: :multi_interface_individual_properties_dbtable,
           storage: table_name
         }
       ) do
    delete_values_statement = """
    DELETE
    FROM #{realm_name}.#{table_name}
    WHERE device_id=:device_id AND interface_id=:interface_id
    """

    delete_values_params = %{
      device_id: device_id,
      interface_id: interface_id
    }

    case execute_query(delete_values_statement, delete_values_params, consistency: :each_quorum) do
      {:ok, %Xandra.Void{}} ->
        :ok

      {:error, reason} ->
        _ =
          Logger.warn(
            "Cannot delete values from #{realm_name}.#{table_name}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  defp delete_values(
         realm_name,
         device_id,
         %InterfaceDescriptor{
           storage_type: :multi_interface_individual_datastream_dbtable
         } = interface_descriptor
       ) do
    with {:ok, result} <-
           fetch_all_paths_and_endpoint_ids(realm_name, device_id, interface_descriptor),
         :ok <- delete_all_paths_values(realm_name, device_id, interface_descriptor, result) do
      delete_all_paths(realm_name, device_id, interface_descriptor)
    end
  end

  defp delete_path_values(
         realm_name,
         device_id,
         %InterfaceDescriptor{
           interface_id: interface_id,
           storage_type: :multi_interface_individual_datastream_dbtable,
           storage: table_name
         },
         endpoint_id,
         path
       ) do
    delete_path_values_statement = """
    DELETE
    FROM #{realm_name}.#{table_name}
    WHERE device_id=:device_id AND interface_id=:interface_id
      AND endpoint_id=:endpoint_id AND path=:path
    """

    delete_path_values_params = %{
      device_id: device_id,
      interface_id: interface_id,
      endpoint_id: endpoint_id,
      path: path
    }

    # TODO is :quorum what we truly want?
    case execute_query(delete_path_values_statement, delete_path_values_params,
           consistency: :quorum
         ) do
      {:ok, %Xandra.Void{}} ->
        :ok

      {:error, reason} ->
        _ =
          Logger.warn("Database error: cannot delete path values. Reason: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  defp delete_all_paths_values(realm_name, device_id, interface_descriptor, all_paths) do
    Enum.reduce_while(all_paths, :ok, fn %{endpoint_id: endpoint_id, path: path}, _acc ->
      case delete_path_values(realm_name, device_id, interface_descriptor, endpoint_id, path) do
        :ok ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp fetch_all_paths_and_endpoint_ids(
         realm_name,
         device_id,
         %InterfaceDescriptor{
           interface_id: interface_id,
           storage_type: :multi_interface_individual_datastream_dbtable
         }
       ) do
    all_paths_statement = """
    SELECT endpoint_id, path
    FROM #{realm_name}.individual_properties
    WHERE device_id=:device_id AND interface_id=:interface_id
    """

    all_paths_params = %{
      device_id: device_id,
      interface_id: interface_id
    }

    case execute_query(all_paths_statement, all_paths_params, consistency: :quorum) do
      # TODO check return type: now it's a list and not a CQEx.result
      {:ok, %Xandra.Page{} = page} ->
        {:ok, Enum.to_list(page)}

      {:error, reason} ->
        _ =
          Logger.warn(
            "Cannot fetch paths and endpoint ids on #{realm_name}, interface id #{interface_id}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  defp delete_all_paths(
         realm_name,
         device_id,
         %InterfaceDescriptor{
           interface_id: interface_id,
           storage_type: :multi_interface_individual_datastream_dbtable
         }
       ) do
    delete_paths_statement = """
    DELETE
    FROM #{realm_name}.individual_properties
    WHERE device_id=:device_id AND interface_id=:interface_id
    """

    delete_paths_params = %{
      device_id: device_id,
      interface_id: interface_id
    }

    case execute_query(delete_paths_statement, delete_paths_params, consistency: :each_quorum) do
      {:ok, %Xandra.Void{}} ->
        :ok

      {:error, reason} ->
        _ =
          Logger.warn(
            "Cannot delete path values on #{realm_name}, interface id #{interface_id}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  def interface_available_versions(realm_name, interface_name) do
    with true <- verify_realm_ok(realm_name) do
      do_interface_available_version(realm_name, interface_name)
    end
  end

  defp do_interface_available_version(realm_name, interface_name) do
    interface_versions_statement = """
    SELECT major_version, minor_version
    FROM #{realm_name}.interfaces
    WHERE name = :interface_name
    """

    interface_versions_params = %{
      interface_name: interface_name
    }

    case execute_query(interface_versions_statement, interface_versions_params,
           consistency: :quorum
         ) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [] ->
            {:error, :interface_not_found}

          result ->
            {:ok, result}
        end

      {:error, reason} ->
        _ =
          Logger.warn("Cannot get available versions for #{interface_name}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  def is_interface_major_available?(realm_name, interface_name, interface_major) do
    case Utils.verify_realm_ok(realm_name) do
      true ->
        do_is_interface_major_available?(realm_name, interface_name, interface_major)

      {:error, :invalid_realm_name} ->
        _ =
          Logger.warn(
            "Cannot retrieve major #{interface_major} for interface #{interface_name} on #{realm_name}: invalid realm name",
            tag: "db_error"
          )

        {:error, :invalid_realm_name}
    end
  end

  defp do_is_interface_major_available?(realm_name, interface_name, interface_major) do
    interface_available_major_statement = """
    SELECT COUNT(*)
    FROM #{realm_name}.interfaces
    WHERE name = :interface_name AND major_version = :interface_major
    """

    interface_available_major_params = %{
      interface_name: interface_name,
      interface_major: interface_major
    }

    case execute_query(interface_available_major_statement, interface_available_major_params,
           consistency: :quorum
         ) do
      {:ok, %Xandra.Page{} = page} ->
        [%{count: count}] = Enum.to_list(page)
        {:ok, count != 0}

      {:error, reason} ->
        _ =
          Logger.warn(
            "Cannot get major #{interface_major} versions for #{interface_name}: #{inspect(reason)}.",
            tag: "is_interface_major_available_fail"
          )

        {:error, :database_error}
    end
  end

  defp normalize_interface_name(interface_name) do
    String.replace(interface_name, "-", "")
    |> String.downcase()
  end

  def check_interface_name_collision(realm_name, interface_name) do
    with true <- verify_realm_ok(realm_name) do
      do_check_interface_name_collision(realm_name, interface_name)
    end
  end

  defp do_check_interface_name_collision(realm_name, interface_name) do
    normalized_interface = normalize_interface_name(interface_name)

    all_names_statement = """
    SELECT DISTINCT name
    FROM #{realm_name}.interfaces
    """

    case execute_query(all_names_statement, %{}, consistency: :quorum) do
      {:ok, %Xandra.Page{} = page} ->
        # TODO check type of element here
        Enum.reduce_while(Enum.to_list(page), :ok, fn %{name: name}, _acc ->
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

      {:error, reason} ->
        Logger.warn(
          "Cannot check interface name collision for #{interface_name}: #{inspect(reason)}.",
          tag: "db_error"
        )

        {:error, :database_error}
    end
  end

  def fetch_interface(realm_name, interface_name, interface_major, opts \\ []) do
    with true <- verify_realm_ok(realm_name) do
      do_fetch_interface(realm_name, interface_name, interface_major, opts)
    end
  end

  defp do_fetch_interface(realm_name, interface_name, interface_major, opts) do
    with {:ok, interface_row} <-
           retrieve_interface_row(realm_name, interface_name, interface_major, opts),
         {:ok, interface_id} <- Keyword.fetch(interface_row, :interface_id),
         {:ok, mappings} <- fetch_interface_mappings(realm_name, interface_id, include_docs: true) do
      interface = %InterfaceDocument{
        name: interface_row[:name],
        major_version: interface_row[:major_version],
        minor_version: interface_row[:minor_version],
        interface_id: interface_id,
        type: interface_row[:type] |> InterfaceType.from_int(),
        ownership: interface_row[:ownership] |> Ownership.from_int(),
        aggregation: interface_row[:aggregation] |> Aggregation.from_int(),
        mappings: mappings,
        description: interface_row[:description],
        doc: interface_row[:doc]
      }

      {:ok, interface}
    end
  end

  defp retrieve_interface_row(realm_name, interface_name, interface_major, opts) do
    case Astarte.DataAccess.Interface.retrieve_interface_row(
           realm_name,
           interface_name,
           interface_major,
           opts
         ) do
      {:ok, interface_row} ->
        {:ok, interface_row}

      {:error, :interface_not_found} ->
        _ =
          Logger.warn(
            "Interface row #{interface_name} v#{interface_major} not found.",
            tag: "retrieve_interface_fail"
          )

        {:error, :interface_not_found}

      {:error, reason} ->
        _ =
          Logger.warn(
            "Cannot retrieve interface row for #{interface_name} v#{interface_major}: #{inspect(reason)}.",
            tag: "retrieve_interface_fail"
          )

        {:error, :database_error}
    end
  end

  defp fetch_interface_mappings(realm_name, interface_id, opts) do
    with {:error, reason} <-
           Astarte.DataAccess.Mappings.fetch_interface_mappings(realm_name, interface_id, opts) do
      _ =
        Logger.warn(
          "Cannot retrieve interface mappings for #{interface_id} : #{inspect(reason)}.",
          tag: "db_error"
        )

      {:error, :database_error}
    end
  end

  def get_interfaces_list(realm_name) do
    with true <- verify_realm_ok(realm_name) do
      do_get_interfaces_list(realm_name)
    end
  end

  defp do_get_interfaces_list(realm_name) do
    all_names_statement = """
    SELECT DISTINCT name
    FROM #{realm_name}.interfaces
    """

    case execute_query(all_names_statement, %{}, consistency: :quorum) do
      {:ok, %Xandra.Page{} = page} ->
        # TODO check type of element here
        list =
          page
          |> Enum.to_list()
          |> Enum.map(fn %{name: name} -> name end)

        {:ok, list}

      {:error, reason} ->
        Logger.warn("Cannot get interface list for #{realm_name}: #{inspect(reason)}.",
          tag: "db_error"
        )

        {:error, :database_error}
    end
  end

  def has_interface_simple_triggers?(realm_name, object_id) do
    with true <- verify_realm_ok(realm_name) do
      do_has_interface_simple_triggers?(realm_name, object_id)
    end
  end

  defp do_has_interface_simple_triggers?(realm_name, interface_id) do
    # FIXME: hardcoded object type here
    simple_triggers_statement = """
    SELECT COUNT(*)
    FROM #{realm_name}.simple_triggers
    WHERE object_id=:object_id AND object_type=2
    """

    simple_triggers_params = %{object_id: interface_id}

    case execute_query(simple_triggers_statement, simple_triggers_params, consistency: :quorum) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [%{count: 0}] -> {:ok, false}
          [%{count: _n}] -> {:ok, true}
        end

      {:error, reason} ->
        _ =
          Logger.warn(
            "Cannot check triggers on interface_id #{interface_id}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  def get_jwt_public_key_pem(realm_name) do
    with true <- verify_realm_ok(realm_name) do
      do_get_jwt_public_key_pem(realm_name)
    end
  end

  defp do_get_jwt_public_key_pem(realm_name) do
    get_pem_statement = @query_jwt_public_key_pem |> String.replace(":realm_name", realm_name)

    case execute_query(get_pem_statement, %{}) do
      {:ok, %Xandra.Page{} = page} ->
        [%{"system.blobasvarchar(value)": pem}] = Enum.to_list(page)
        {:ok, pem}

      {:error, reason} ->
        _ =
          Logger.warn(
            "Cannot get public key for #{realm_name}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :public_key_not_found}
    end
  end

  def update_jwt_public_key_pem(realm_name, jwt_public_key_pem) do
    with true <- verify_realm_ok(realm_name) do
      do_update_jwt_public_key_pem(realm_name, jwt_public_key_pem)
    end
  end

  defp do_update_jwt_public_key_pem(realm_name, jwt_public_key_pem) do
    update_statement =
      @query_insert_jwt_public_key_pem |> String.replace(":realm_name", realm_name)

    update_params = %{pem: jwt_public_key_pem}

    case execute_query(update_statement, update_params) do
      {:ok, %Xandra.Void{}} ->
        :ok

      {:error, reason} ->
        _ =
          Logger.warn(
            "Cannot update public key for #{realm_name}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :cant_update_public_key}
    end
  end

  def install_trigger(realm_name, trigger) do
    with true <- verify_realm_ok(realm_name) do
      do_install_trigger(realm_name, trigger)
    end
  end

  defp do_install_trigger(realm_name, trigger) do
    # TODO: use IF NOT EXISTS
    insert_by_name_query_statement =
      "INSERT INTO #{realm_name}.kv_store (group, key, value) VALUES ('triggers-by-name', :trigger_name, uuidAsBlob(:trigger_uuid));"

    insert_by_name_params = %{
      trigger_name: trigger.name,
      trigger_uuid: trigger.trigger_uuid
    }

    # TODO: use IF NOT EXISTS
    insert_query_statement =
      "INSERT INTO #{realm_name}.kv_store (group, key, value) VALUES ('triggers', :trigger_uuid, :trigger_data);"

    insert_params = %{
      trigger_uuid: :uuid.uuid_to_string(trigger.trigger_uuid) |> to_string(),
      trigger_data: Trigger.encode(trigger)
    }

    batch_result =
      execute_batch(
        [
          {insert_by_name_query_statement, insert_by_name_params},
          {insert_query_statement, insert_params}
        ],
        # TODO check consistency level (one was the default)
        consistency: :one
      )

    case batch_result do
      :ok ->
        :ok

      {:error, reason} ->
        _ =
          Logger.warn("Cannot install trigger #{trigger.name}: #{inspect(reason)}.",
            tag: "db_error"
          )

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
    with true <- verify_realm_ok(realm_name) do
      do_install_simple_trigger(
        realm_name,
        object_id,
        object_type,
        parent_trigger_id,
        simple_trigger_id,
        simple_trigger,
        trigger_target
      )
    end
  end

  defp do_install_simple_trigger(
         realm_name,
         object_id,
         object_type,
         parent_trigger_id,
         simple_trigger_id,
         simple_trigger,
         trigger_target
       ) do
    insert_simple_trigger_statement = """
    INSERT INTO #{realm_name}.simple_triggers
    (object_id, object_type, parent_trigger_id, simple_trigger_id, trigger_data, trigger_target)
    VALUES (:object_id, :object_type, :parent_trigger_id, :simple_trigger_id, :simple_trigger_data, :trigger_target_data);
    """

    insert_simple_trigger_params = %{
      object_id: object_id,
      object_type: object_type,
      parent_trigger_id: parent_trigger_id,
      simple_trigger_id: simple_trigger_id,
      simple_trigger_data: SimpleTriggerContainer.encode(simple_trigger),
      trigger_target_data: TriggerTargetContainer.encode(trigger_target)
    }

    astarte_ref = %AstarteReference{
      object_type: object_type,
      object_uuid: object_id
    }

    insert_simple_trigger_by_uuid_statement =
      "INSERT INTO #{realm_name}.kv_store (group, key, value) VALUES ('simple-triggers-by-uuid', :simple_trigger_id, :astarte_ref);"

    insert_simple_trigger_by_uuid_params = %{
      simple_trigger_id: :uuid.uuid_to_string(simple_trigger_id),
      astarte_ref: AstarteReference.encode(astarte_ref)
    }

    # TODO check consistency level (one was the default)
    with {:ok, %Xandra.Void{}} <-
           execute_query(insert_simple_trigger_statement, insert_simple_trigger_params,
             consistency: :one
           ),
         {:ok, %Xandra.Void{}} <-
           execute_query(
             insert_simple_trigger_by_uuid_statement,
             insert_simple_trigger_by_uuid_params,
             consistency: :one
           ) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.warn("Cannot install simple trigger: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :cannot_install_simple_trigger}
    end
  end

  def install_trigger_policy_link(realm_name, trigger_uuid, trigger_policy) do
    with true <- verify_realm_ok(realm_name) do
      do_install_trigger_policy_link(realm_name, trigger_uuid, trigger_policy)
    end
  end

  def do_install_trigger_policy_link(_realm_name, _trigger_uuid, nil) do
    :ok
  end

  def do_install_trigger_policy_link(realm_name, trigger_uuid, trigger_policy) do
    insert_trigger_with_policy_statement =
      "INSERT INTO #{realm_name}.kv_store (group, key, value) VALUES (:policy_group, :trigger_uuid, uuidAsBlob(:trigger_uuid))"

    insert_trigger_with_policy_params = %{
      policy_group: "triggers-with-policy-#{trigger_policy}",
      trigger_uuid: :uuid.uuid_to_string(trigger_uuid) |> to_string()
    }

    insert_trigger_to_policy_statement =
      "INSERT INTO #{realm_name}.kv_store (group, key, value) VALUES ('trigger_to_policy',  :trigger_uuid, :trigger_policy);"

    insert_trigger_to_policy_params = %{
      trigger_uuid: :uuid.uuid_to_string(trigger_uuid) |> to_string,
      trigger_policy: trigger_policy
    }

    # TODO check consistency level (one was the default)
    with {:ok, %Xandra.Void{}} <-
           execute_query(
             insert_trigger_with_policy_statement,
             insert_trigger_with_policy_params,
             consistency: :one
           ),
         {:ok, %Xandra.Void{}} <-
           execute_query(
             insert_trigger_to_policy_statement,
             insert_trigger_to_policy_params,
             consistency: :one
           ) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.warn("Cannot install policy link: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :cannot_install_trigger_policy_link}
    end
  end

  def retrieve_trigger_uuid(realm_name, trigger_name, format \\ :string) do
    with true <- verify_realm_ok(realm_name) do
      do_retrieve_trigger_uuid(realm_name, trigger_name, format)
    end
  end

  defp do_retrieve_trigger_uuid(realm_name, trigger_name, format) do
    trigger_uuid_statement =
      "SELECT value FROM #{realm_name}.kv_store WHERE group='triggers-by-name' AND key=:trigger_name;"

    trigger_uuid_params = %{trigger_name: trigger_name}

    case execute_query(trigger_uuid_statement, trigger_uuid_params, consistency: :one) do
      {:ok, %Xandra.Page{} = page} ->
        page
        |> Enum.to_list()
        |> check_trigger_uuid(format)

      {:error, reason} ->
        _ =
          Logger.warn("Cannot retrieve uuid for #{trigger_name}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :cannot_retrieve_trigger_uuid}
    end
  end

  defp check_trigger_uuid([], _format) do
    {:error, :trigger_not_found}
  end

  defp check_trigger_uuid(value, format) do
    [%{value: trigger_uuid}] = value

    case format do
      :string ->
        {:ok, :uuid.uuid_to_string(trigger_uuid) |> to_string()}

      :bytes ->
        {:ok, trigger_uuid}
    end
  end

  def delete_trigger_policy_link(realm_name, trigger_uuid, trigger_policy) do
    with true <- verify_realm_ok(realm_name) do
      do_delete_trigger_policy_link(realm_name, trigger_uuid, trigger_policy)
    end
  end

  defp do_delete_trigger_policy_link(_realm_name, _trigger_uuid, nil) do
    :ok
  end

  defp do_delete_trigger_policy_link(realm_name, trigger_uuid, trigger_policy) do
    delete_trigger_with_policy_statement =
      "DELETE FROM #{realm_name}.kv_store WHERE group=:policy_group AND key=:trigger_uuid;"

    delete_trigger_with_policy_params = %{
      policy_group: "triggers-with-policy-#{trigger_policy}",
      trigger_uuid: :uuid.uuid_to_string(trigger_uuid) |> to_string()
    }

    delete_trigger_to_policy_statement =
      "DELETE FROM #{realm_name}.kv_store WHERE group='trigger_to_policy' AND key=:trigger_uuid;"

    delete_trigger_to_policy_params = %{
      trigger_uuid: :uuid.uuid_to_string(trigger_uuid) |> to_string()
    }

    # TODO check consistency level (one was the default)
    with {:ok, %Xandra.Void{}} <-
           execute_query(
             delete_trigger_with_policy_statement,
             delete_trigger_with_policy_params,
             consistency: :one
           ),
         {:ok, %Xandra.Void{}} <-
           execute_query(
             delete_trigger_to_policy_statement,
             delete_trigger_to_policy_params,
             consistency: :one
           ) do
      :ok
    else
      {:error, reason} ->
        _ =
          Logger.warn("Cannot delete policy link: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :cannot_delete_trigger_policy_link}
    end
  end

  def delete_trigger(realm_name, trigger_name) do
    with true <- verify_realm_ok(realm_name) do
      do_delete_trigger(realm_name, trigger_name)
    end
  end

  defp do_delete_trigger(realm_name, trigger_name) do
    with {:ok, trigger_uuid} <- retrieve_trigger_uuid(realm_name, trigger_name) do
      delete_trigger_by_name_statement =
        "DELETE FROM #{realm_name}.kv_store WHERE group='triggers-by-name' AND key=:trigger_name;"

      delete_trigger_by_name_params = %{trigger_name: trigger_name}

      delete_trigger_statement =
        "DELETE FROM #{realm_name}.kv_store WHERE group='triggers' AND key=:trigger_uuid;"

      delete_trigger_params = %{trigger_uuid: trigger_uuid}

      with {:ok, %Xandra.Void{}} <-
             execute_query(delete_trigger_statement, delete_trigger_params),
           {:ok, %Xandra.Void{}} <-
             execute_query(
               delete_trigger_by_name_statement,
               delete_trigger_by_name_params
             ) do
        :ok
      else
        {:error, reason} ->
          _ =
            Logger.warn("Cannot delete trigger #{trigger_name}: #{inspect(reason)}.",
              tag: "db_error"
            )

          {:error, :cannot_delete_trigger}
      end
    end
  end

  def get_triggers_list(realm_name) do
    with true <- verify_realm_ok(realm_name) do
      do_get_triggers_list(realm_name)
    end
  end

  defp do_get_triggers_list(realm_name) do
    triggers_list_statement =
      "SELECT key FROM #{realm_name}.kv_store WHERE group = 'triggers-by-name';"

    case execute_query(triggers_list_statement, %{}, consistency: :one) do
      {:ok, %Xandra.Page{} = page} ->
        list =
          page
          |> Enum.to_list()
          |> Enum.map(fn %{key: value} -> value end)

        {:ok, list}

      {:error, reason} ->
        _ =
          Logger.warn("Cannot list triggers in #{realm_name}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :cannot_list_triggers}
    end
  end

  def retrieve_trigger(realm_name, trigger_name) do
    with true <- verify_realm_ok(realm_name) do
      do_retrieve_trigger(realm_name, trigger_name)
    end
  end

  defp do_retrieve_trigger(realm_name, trigger_name) do
    with {:ok, trigger_uuid} <- retrieve_trigger_uuid(realm_name, trigger_name) do
      retrieve_trigger_statement =
        "SELECT value FROM #{realm_name}.kv_store WHERE group='triggers' AND key=:trigger_uuid;"

      retrieve_trigger_params = %{trigger_uuid: trigger_uuid}

      case execute_query(retrieve_trigger_statement, retrieve_trigger_params, consistency: :one) do
        {:ok, %Xandra.Page{} = page} ->
          case Enum.to_list(page) do
            [] ->
              {:error, :trigger_not_found}

            [%{value: trigger_data}] ->
              {:ok, Trigger.decode(trigger_data)}
          end

        {:error, reason} ->
          _ =
            Logger.warn("Cannot retrieve trigger #{trigger_name}: #{inspect(reason)}.",
              tag: "db_error"
            )

          {:error, :cannot_retrieve_trigger}
      end
    end
  end

  def retrieve_tagged_simple_trigger(realm_name, parent_trigger_uuid, simple_trigger_uuid) do
    with true <- verify_realm_ok(realm_name) do
      do_retrieve_tagged_simple_trigger(realm_name, parent_trigger_uuid, simple_trigger_uuid)
    end
  end

  # TODO: simple_trigger_uuid is required due how we made the compound key
  # should we move simple_trigger_uuid to the first part of the key?
  defp do_retrieve_tagged_simple_trigger(realm_name, parent_trigger_uuid, simple_trigger_uuid) do
    with %{object_uuid: object_id, object_type: object_type} <-
           retrieve_simple_trigger_astarte_ref(realm_name, simple_trigger_uuid) do
      retrieve_simple_trigger_statement = """
      SELECT trigger_data
      FROM #{realm_name}.simple_triggers
      WHERE object_id=:object_id AND object_type=:object_type AND
            parent_trigger_id=:parent_trigger_id AND simple_trigger_id=:simple_trigger_id
      """

      retrieve_simple_trigger_params = %{
        object_id: object_id,
        object_type: object_type,
        parent_trigger_id: parent_trigger_uuid,
        simple_trigger_id: simple_trigger_uuid
      }

      case execute_query(
             retrieve_simple_trigger_statement,
             retrieve_simple_trigger_params,
             consistency: :one
           ) do
        {:ok, %Xandra.Page{} = page} ->
          [%{trigger_data: trigger_data}] = Enum.to_list(page)

          {
            :ok,
            %TaggedSimpleTrigger{
              object_id: object_id,
              object_type: object_type,
              simple_trigger_container: SimpleTriggerContainer.decode(trigger_data)
            }
          }

        {:error, reason} ->
          _ =
            Logger.warn("Cannot retrieve tagged simple trigger: #{inspect(reason)}.",
              tag: "db_error"
            )

          {:error, :cannot_retrieve_simple_trigger}
      end
    end
  end

  def delete_simple_trigger(realm_name, parent_trigger_uuid, simple_trigger_uuid) do
    with true <- verify_realm_ok(realm_name) do
      do_delete_simple_trigger(realm_name, parent_trigger_uuid, simple_trigger_uuid)
    end
  end

  defp do_delete_simple_trigger(realm_name, parent_trigger_uuid, simple_trigger_uuid) do
    with %{object_uuid: object_id, object_type: object_type} <-
           retrieve_simple_trigger_astarte_ref(realm_name, simple_trigger_uuid) do
      delete_simple_trigger_statement = """
      DELETE FROM #{realm_name}.simple_triggers
      WHERE object_id=:object_id AND object_type=:object_type AND
            parent_trigger_id=:parent_trigger_id AND simple_trigger_id=:simple_trigger_id
      """

      delete_simple_trigger_params = %{
        object_id: object_id,
        object_type: object_type,
        parent_trigger_id: parent_trigger_uuid,
        simple_trigger_id: simple_trigger_uuid
      }

      delete_astarte_ref_statement =
        "DELETE FROM #{realm_name}.kv_store WHERE group='simple-triggers-by-uuid' AND key=:simple_trigger_uuid;"

      delete_astarte_ref_params = %{
        simple_trigger_uuid: :uuid.uuid_to_string(simple_trigger_uuid)
      }

      # TODO check consistency level (one was the default)
      with {:ok, %Xandra.Void{}} <-
             execute_query(delete_simple_trigger_statement, delete_simple_trigger_params,
               consistency: :one
             ),
           {:ok, %Xandra.Void{}} <-
             execute_query(delete_astarte_ref_statement, delete_astarte_ref_params,
               consistency: :one
             ) do
        :ok
      else
        {:error, reason} ->
          _ = Logger.warn("Cannot delete simple trigger: #{inspect(reason)}.", tag: "db_error")
          {:error, :cannot_delete_simple_trigger}
      end
    end
  end

  defp retrieve_simple_trigger_astarte_ref(realm_name, simple_trigger_uuid) do
    retrieve_astarte_ref_statement =
      "SELECT value FROM #{realm_name}.kv_store WHERE group='simple-triggers-by-uuid' AND key=:simple_trigger_uuid;"

    retrieve_astarte_ref_params = %{
      simple_trigger_uuid: :uuid.uuid_to_string(simple_trigger_uuid)
    }

    case execute_query(retrieve_astarte_ref_statement, retrieve_astarte_ref_params) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [] -> {:error, :trigger_not_found}
          [%{value: astarte_ref_blob}] -> AstarteReference.decode(astarte_ref_blob)
        end

      {:error, reason} ->
        _ =
          Logger.warn("Cannot retrieve simple trigger astarte refr: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :cannot_retrieve_simple_trigger_astarte_ref}
    end
  end

  def install_new_trigger_policy(realm_name, policy_name, policy_proto) do
    with true <- verify_realm_ok(realm_name) do
      do_install_new_trigger_policy(realm_name, policy_name, policy_proto)
    end
  end

  defp do_install_new_trigger_policy(realm_name, policy_name, policy_proto) do
    insert_query_statement =
      "INSERT INTO #{realm_name}.kv_store (group, key, value) VALUES ('trigger_policy', :policy_name, :policy_container);"

    insert_query_params = %{
      policy_name: policy_name,
      policy_container: policy_proto
    }

    # TODO check consistency level (one was the default)
    case execute_query(insert_query_statement, insert_query_params, consistency: :one) do
      {:ok, %Xandra.Void{}} ->
        :ok

      {:error, reason} ->
        _ =
          Logger.warn("Cannot install policy #{policy_name}: #{inspect(reason)}.", tag: "db_error")

        {:error, :cannot_install_trigger_policy}
    end
  end

  def get_trigger_policies_list(realm_name) do
    with true <- verify_realm_ok(realm_name) do
      do_get_trigger_policies_list(realm_name)
    end
  end

  defp do_get_trigger_policies_list(realm_name) do
    trigger_policies_list_statement = """
    SELECT key FROM #{realm_name}.kv_store WHERE group=:group_name
    """

    trigger_policies_list_params = %{group_name: "trigger_policy"}

    case execute_query(
           trigger_policies_list_statement,
           trigger_policies_list_params,
           consistency: :quorum
         ) do
      {:ok, %Xandra.Page{} = page} ->
        list =
          page
          |> Enum.to_list()
          # TODO check type here
          |> Enum.map(fn %{key: value} -> value end)

        {:ok, list}

      {:error, reason} ->
        _ =
          Logger.warn("Cannot list trigger policies on #{realm_name}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  def fetch_trigger_policy(realm_name, policy_name) do
    with true <- verify_realm_ok(realm_name) do
      do_fetch_trigger_policy(realm_name, policy_name)
    end
  end

  defp do_fetch_trigger_policy(realm_name, policy_name) do
    policy_cols_statement = """
    SELECT value
    FROM #{realm_name}.kv_store
    WHERE group=:group_name and key=:policy_name
    """

    policy_cols_params = %{
      group_name: "trigger_policy",
      policy_name: policy_name
    }

    case execute_query(policy_cols_statement, policy_cols_params, consistency: :quorum) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [] -> {:error, :policy_not_found}
          [%{value: value}] -> {:ok, value}
        end

      {:error, reason} ->
        _ = Logger.warn("Cannot get policy #{policy_name}: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def check_policy_has_triggers(realm_name, policy_name) do
    with true <- verify_realm_ok(realm_name) do
      do_check_policy_has_triggers(realm_name, policy_name)
    end
  end

  defp do_check_policy_has_triggers(realm_name, policy_name) do
    devices_statement = "SELECT key FROM #{realm_name}.kv_store WHERE group=:group_name LIMIT 1"

    devices_params = %{
      group_name: "triggers-with-policy-#{policy_name}"
    }

    case execute_query(devices_statement, devices_params, consistency: :quorum) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [] ->
            {:ok, false}

          [%{key: _device_id}] ->
            {:ok, true}
        end

      {:error, reason} ->
        _ =
          Logger.warn(
            "Cannot check #{policy_name}: #{inspect(reason)}.",
            tag: "db_error"
          )

        {:error, :database_error}
    end
  end

  def delete_trigger_policy(realm_name, policy_name) do
    with true <- verify_realm_ok(realm_name) do
      do_delete_trigger_policy(realm_name, policy_name)
    end
  end

  defp do_delete_trigger_policy(realm_name, policy_name) do
    _ =
      Logger.info("Delete trigger policy.",
        policy_name: policy_name,
        tag: "db_error"
      )

    delete_policy_statement =
      "DELETE FROM #{realm_name}.kv_store WHERE group= :group_name AND key= :policy_name"

    delete_policy_params = %{
      group_name: "trigger_policy",
      policy_name: policy_name
    }

    # TODO check warning
    delete_triggers_with_policy_group_statement =
      "DELETE FROM #{realm_name}.kv_store WHERE group=:group_name"

    delete_triggers_with_policy_group_params = %{
      group_name: "triggers-with-policy-#{policy_name}"
    }

    delete_trigger_to_policy_statement =
      "DELETE FROM #{realm_name}.kv_store WHERE group=:group_name;"

    delete_trigger_to_policy_params = %{
      group_name: "trigger_to_policy"
    }

    batch_result =
      execute_batch(
        [
          {delete_policy_statement, delete_policy_params},
          {delete_triggers_with_policy_group_statement, delete_triggers_with_policy_group_params},
          {delete_trigger_to_policy_statement, delete_trigger_to_policy_params}
        ],
        consistency: :each_quorum
      )

    case batch_result do
      :ok ->
        :ok

      {:error, reason} ->
        _ = Logger.error("Cannot delete #{policy_name}: #{inspect(reason)}.", tag: "db_error")

        {:error, :database_error}
    end
  end

  def check_trigger_policy_already_present(realm_name, policy_name) do
    with true <- verify_realm_ok(realm_name) do
      do_check_trigger_policy_already_present(realm_name, policy_name)
    end
  end

  defp do_check_trigger_policy_already_present(realm_name, policy_name) do
    policy_cols_statement = """
    SELECT COUNT(*)
    FROM #{realm_name}.kv_store
    WHERE group= :group_name and key= :policy_name
    """

    policy_cols_params = %{
      group_name: "trigger_policy",
      policy_name: policy_name
    }

    case execute_query(policy_cols_statement, policy_cols_params, consistency: :quorum) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [%{count: 0}] -> {:ok, false}
          [%{count: _n}] -> {:ok, true}
        end

      {:error, reason} ->
        _ =
          Logger.warn("Cannot verify policy #{policy_name}: #{inspect(reason)}.", tag: "db_error")

        {:error, :database_error}
    end
  end

  defp execute_batch(queries, opts) when length(queries) < @max_batch_queries do
    Xandra.Cluster.run(:xandra, fn conn ->
      do_execute_batch(conn, queries, opts)
    end)
  end

  defp execute_batch(queries, opts) do
    _ =
      Logger.debug(
        "Trying to run #{inspect(length(queries))} queries, not running in batched mode."
      )

    Enum.reduce_while(queries, :ok, fn {statement, params}, _acc ->
      Xandra.Cluster.run(:xandra, fn conn ->
        with {:ok, prepared} <- prepare_query(conn, statement) do
          case Xandra.execute(conn, prepared, params, opts ++ query_opts()) do
            {:ok, _result} ->
              {:cont, :ok}

            {:error, err} ->
              _ =
                Logger.warn(
                  "Failed due to database error: #{inspect(err)}. Changes will not be undone!",
                  tag: "db_error"
                )

              {:halt, {:error, :database_error}}
          end
        end
      end)
    end)
  end

  defp do_execute_batch(conn, queries, opts) do
    batch =
      Enum.reduce(queries, Xandra.Batch.new(:logged), fn {statement, params}, batch ->
        with {:ok, prepared} <- prepare_query(conn, statement) do
          Xandra.Batch.add(batch, prepared, params)
        end
      end)

    res = Xandra.execute(conn, batch, opts ++ query_opts())

    case res do
      {:ok, _result} ->
        :ok

      {:error, reason} ->
        _ =
          Logger.warn("Failed batch due to database error: #{inspect(reason)}.",
            tag: "batch_db_error"
          )

        {:error, :database_error}
    end
  end

  defp execute_query(statement, params \\ %{}, opts \\ []) do
    Xandra.Cluster.run(:xandra, fn conn ->
      execute_query(conn, statement, params, opts ++ query_opts())
    end)
  end

  defp execute_query(conn, statement, params, opts) do
    with {:ok, prepared} <- prepare_query(conn, statement) do
      Xandra.execute(conn, prepared, params, opts)
    end
  end

  defp prepare_query(conn, statement) do
    with {:error, reason} <- Xandra.prepare(conn, statement) do
      _ = Logger.warn("Cannot prepare query: #{inspect(reason)}.", tag: "db_error")
      {:error, :database_error}
    end
  end

  defp query_opts() do
    [uuid_format: :binary, timestamp_format: :integer]
  end

  defp verify_realm_ok(realm_name) do
    with {:error, :invalid_realm_name} <- Utils.verify_realm_ok(realm_name) do
      _ =
        Logger.warn(
          "Invalid realm name #{realm_name}.",
          tag: "invalid_realm_name"
        )

      {:error, :invalid_realm_name}
    end
  end
end
