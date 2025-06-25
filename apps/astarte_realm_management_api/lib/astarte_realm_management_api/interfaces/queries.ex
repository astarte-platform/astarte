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

defmodule Astarte.RealmManagement.API.Interfaces.Queries do
  @moduledoc """
  Astarte.Realm Management API Interfaces Queries module.
  """

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Interface, as: InterfaceDocument
  alias Astarte.Core.Interface.Type, as: InterfaceType
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.DatabaseRetentionPolicy
  alias Astarte.Core.Mapping.Reliability
  alias Astarte.Core.Mapping.Retention
  alias Astarte.Core.Mapping.ValueType
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  require Logger

  import Ecto.Query

  defp create_one_object_columns_for_mappings(mappings) do
    for %Mapping{endpoint: endpoint, value_type: value_type} <- mappings do
      column_name = CQLUtils.endpoint_to_db_column_name(endpoint)
      cql_type = CQLUtils.mapping_value_type_to_db_type(value_type)
      "#{column_name} #{cql_type}"
    end
    |> Enum.join(~s(,\n))
  end

  def update_interface_storage(_realm_name, _interface_descriptor, []) do
    # No new mappings, nothing to do
    :ok
  end

  def update_interface_storage(
        realm_name,
        %InterfaceDescriptor{storage_type: :one_object_datastream_dbtable, storage: table_name} =
          _interface_descriptor,
        new_mappings
      ) do
    keyspace = Realm.keyspace_name(realm_name)

    add_cols = create_one_object_columns_for_mappings(new_mappings)

    _ =
      Logger.debug("Interface update: going to add #{inspect(add_cols)} to #{table_name}.",
        tag: "db_interface_add_table_cols"
      )

    update_storage_statement =
      """
      ALTER TABLE #{keyspace}.#{table_name}
      ADD (#{add_cols})
      """

    consistency = Consistency.domain_model(:write)

    with {:ok, _} <- Repo.query(update_storage_statement, [], consistency: consistency) do
      :ok
    end
  end

  def update_interface_storage(_realm_name, _interface_descriptor, _new_mappings) do
    :ok
  end

  def update_interface(
        realm_name,
        interface_descriptor,
        new_mappings,
        automaton,
        description,
        doc
      ) do
    keyspace = Realm.keyspace_name(realm_name)

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

    changes = [
      minor_version: minor,
      automaton_accepting_states: automaton_accepting_states_bin,
      automaton_transitions: automaton_transitions_bin,
      description: description,
      doc: doc
    ]

    update_query =
      from Interface,
        prefix: ^keyspace,
        where: [name: ^interface_name],
        where: [major_version: ^major],
        update: [set: ^changes]

    update_interface_query = Repo.to_sql(:update_all, update_query)

    insert_mapping_queries =
      for mapping <- new_mappings do
        insert_mapping_query(
          keyspace,
          interface_id,
          interface_name,
          major,
          minor,
          interface_type,
          mapping
        )
      end

    consistency = Consistency.domain_model(:write)

    Exandra.execute_batch(
      Repo,
      %Exandra.Batch{
        queries: [update_interface_query | insert_mapping_queries]
      },
      consistency: consistency
    )
  end

  # TODO: this was needed when Cassandra used to generate endpoint IDs
  # it might be a good idea to drop this and generate those IDs in A.C.Mapping.EndpointsAutomaton
  defp replace_automaton_acceptings_with_ids(accepting_states, interface_name, major) do
    Map.new(accepting_states, fn state ->
      {state_index, endpoint} = state
      endpoint_id = CQLUtils.endpoint_id(interface_name, major, endpoint)

      {state_index, endpoint_id}
    end)
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

  @doc """
  Fetches an `Astarte.Core.Interface` by its name and major version in a specified realm.

  ## Parameters
  - `realm`: The name of the realm from which to fetch the interface major versions.
  - `interface_versions_list`: A list of interface versions, each containing a `:major_version` key.

  ## Returns
  - `{:ok, interface_majors}`: A tuple containing `:ok` and a list of major versions.
  - `{:error, :interface_not_found}`: If the interface is not found in the specified realm.
  - `{:error, reason}`: If an error occurs during the fetch operation.
  """
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
      endpoints_query = from Endpoint, where: [interface_id: ^interface.interface_id]

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
end
