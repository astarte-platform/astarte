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

defmodule Astarte.RealmManagement.Interfaces.Queries do
  @moduledoc """
  Astarte Realm Management Interfaces Queries module.
  """
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.Interface, as: InterfaceDocument
  alias Astarte.Core.Interface.Aggregation
  alias Astarte.Core.Interface.Ownership
  alias Astarte.Core.Interface.Type, as: InterfaceType
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.DatabaseRetentionPolicy
  alias Astarte.Core.Mapping.Reliability
  alias Astarte.Core.Mapping.Retention
  alias Astarte.Core.Mapping.ValueType
  alias Astarte.Core.StorageType
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.CSystem
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Realms.IndividualProperty
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Realms.SimpleTrigger
  alias Astarte.DataAccess.Repo
  alias Astarte.RealmManagement.CreateDatastreamIndividualMultiInterface

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

  @doc """
    Installs an interface in the specified realm.
    This function creates the necessary tables and inserts the interface metadata into the database.
    It handles both individual and object aggregation types, and it also manages the automaton transitions and accepting states.

    ## Parameters
    - `realm_name`: The name of the realm where the interface will be installed.
    - `interface_document`: The interface document containing the interface metadata and mappings.
    - `automaton`: A tuple containing the automaton transitions and accepting states.

    ## Returns
    - `:ok`: If the interface was successfully installed.
    - `{:error, reason}`: If there was an error during the installation process.
  """
  def install_interface(realm_name, interface_document, automaton) do
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

  defp replace_automaton_acceptings_with_ids(accepting_states, interface_name, major) do
    Enum.reduce(accepting_states, %{}, fn state, new_states ->
      {state_index, endpoint} = state

      Map.put(new_states, state_index, CQLUtils.endpoint_id(interface_name, major, endpoint))
    end)
  end

  @doc """
    Fetches all interface names in a specified realm.
    This function retrieves all unique interface names from the database for a given realm.

    ## Parameters
    - `realm_name`: The name of the realm from which to fetch the interface names.

    ## Returns
    - `{:ok, interface_names}`: A tuple containing `:ok` and a list of unique interface names.
    - `{:error, reason}`: If there was an error during the fetch operation.
  """
  def fetch_all_interface_names(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    all_names_query =
      from i in Interface,
        distinct: true,
        select: i.name

    consistency = Consistency.domain_model(:read)
    Repo.fetch_all(all_names_query, prefix: keyspace, consistency: consistency)
  end

  @doc """
  Checks if an interface major version is available in a given realm.
  This function checks if an interface with the specified name and major version exists in the realm.
  If it exists, it returns `true`, indicating that the interface major version is already installed.
  If it does not exist, it returns `false`, indicating that the interface major version is available for installation.

  ## Parameters
  - `realm_name`: The name of the realm where the interface is being checked.
  - `interface_name`: The name of the interface to check.
  - `interface_major`: The major version of the interface to check.

  ## Returns
  - `true`: If the interface major version is already installed.
  - `false`: If the interface major version is available for installation.
  """
  def interface_major_available?(realm_name, interface_name, interface_major) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from i in Interface,
        where: i.name == ^interface_name,
        where: i.major_version == ^interface_major

    consistency = Consistency.domain_model(:read)

    {:ok, some?} = Repo.some?(query, prefix: keyspace, consistency: consistency)

    some?
  end

  @doc """
  Fetches the maximum storage retention for datastreams in a specified realm.
  This function retrieves the maximum storage retention for datastreams from the key-value store.
  If the value is not found, it defaults to 0, indicating no retention limit.

  ## Parameters
  - `realm_name`: The name of the realm for which to fetch the maximum storage retention.

  ## Returns
  - `{:ok, value}`: A tuple containing `:ok` and the maximum storage retention value as an integer.
  - `{:error, :fetch_error}`: If there was an error fetching the value from the key-value store.
  """
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

  @doc """
  Retrieves all available versions (major and minor) of a given interface within a specified realm.

  ## Parameters
  - `realm_name` (string): The name of the realm to query.
  - `interface_name` (string): The name of the interface whose versions are to be retrieved.

  ## Returns
  - `{:ok, versions}`: On success, returns a list of maps with `:major_version` and `:minor_version` keys for each available version.
  - `{:error, :interface_not_found}`: If the interface does not exist in the specified realm.
  """
  def fetch_interface_versions_list(realm_name, interface_name) do
    keyspace = Realm.keyspace_name(realm_name)

    consistency = Consistency.domain_model(:read)

    interface_versions_query =
      from Interface,
        select: [:major_version, :minor_version],
        where: [name: ^interface_name]

    with {:ok, interface_versions} <-
           Repo.fetch_all(interface_versions_query, prefix: keyspace, consistency: consistency) do
      case interface_versions do
        [] ->
          {:error, :interface_not_found}

        interfaces ->
          major_minor_mapping =
            Enum.map(interfaces, fn interface ->
              [major_version: interface.major_version, minor_version: interface.minor_version]
            end)

          {:ok, major_minor_mapping}
      end
    end
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

  def delete_interface_storage(
        realm_name,
        %InterfaceDescriptor{
          storage_type: :one_object_datastream_dbtable,
          storage: table_name
        } = _interface_descriptor
      ) do
    keyspace = Realm.keyspace_name(realm_name)
    delete_statement = "DROP TABLE IF EXISTS #{keyspace}.#{table_name}"
    consistency = Consistency.domain_model(:write)

    _ = Repo.query!(delete_statement, [], consistency: consistency)
    _ = Logger.info("Deleted #{table_name} table.", tag: "db_delete_interface_table")
    :ok
  end

  def delete_interface_storage(realm_name, %InterfaceDescriptor{} = interface_descriptor) do
    with {:ok, result} <- devices_with_data_on_interface(realm_name, interface_descriptor.name) do
      Enum.reduce_while(result, :ok, fn encoded_device_id, _acc ->
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

  defp delete_values(
         realm_name,
         device_id,
         %InterfaceDescriptor{
           interface_id: interface_id,
           storage_type: :multi_interface_individual_properties_dbtable,
           storage: table_name
         } = _interface_descriptor
       ) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from table_name,
        where: [device_id: ^device_id, interface_id: ^interface_id]

    consistency = Consistency.device_info(:write)

    _ = Repo.delete_all(query, prefix: keyspace, consistency: consistency)

    :ok
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

  defp fetch_all_paths_and_endpoint_ids(
         realm_name,
         device_id,
         %InterfaceDescriptor{
           interface_id: interface_id,
           storage_type: :multi_interface_individual_datastream_dbtable
         } = _interface_descriptor
       ) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from IndividualProperty,
        select: [:endpoint_id, :path],
        where: [device_id: ^device_id, interface_id: ^interface_id]

    consistency = Consistency.device_info(:read)

    with {:ok, properties} <- Repo.fetch_all(query, prefix: keyspace, consistency: consistency) do
      properties =
        Enum.map(properties, fn property ->
          [endpoint_id: property.endpoint_id, path: property.path]
        end)

      {:ok, properties}
    end
  end

  defp delete_all_paths(
         realm_name,
         device_id,
         %InterfaceDescriptor{
           interface_id: interface_id,
           storage_type: :multi_interface_individual_datastream_dbtable
         } = _interface_descriptor
       ) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from IndividualProperty,
        where: [device_id: ^device_id, interface_id: ^interface_id]

    consistency = Consistency.device_info(:write)

    _ = Repo.delete_all(query, consistency: consistency, prefix: keyspace)

    :ok
  end

  defp delete_all_paths_values(realm_name, device_id, interface_descriptor, all_paths) do
    Enum.each(all_paths, fn [endpoint_id: endpoint_id, path: path] ->
      delete_path_values(realm_name, device_id, interface_descriptor, endpoint_id, path)
    end)

    :ok
  end

  def delete_path_values(
        realm_name,
        device_id,
        %InterfaceDescriptor{
          interface_id: interface_id,
          storage_type: :multi_interface_individual_datastream_dbtable,
          storage: table_name
        } = _interface_descriptor,
        endpoint_id,
        path
      ) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from table_name,
        where: [
          device_id: ^device_id,
          interface_id: ^interface_id,
          endpoint_id: ^endpoint_id,
          path: ^path
        ]

    consistency = Consistency.device_info(:write)

    _ = Repo.delete_all(query, prefix: keyspace, consistency: consistency)

    :ok
  end

  defp devices_with_data_on_interface(realm_name, interface_name) do
    group_name = "devices-with-data-on-interface-#{interface_name}-v0"
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from map in KvStore,
        select: map.key,
        where: [group: ^group_name]

    consistency = Consistency.domain_model(:read)

    Repo.fetch_all(query, prefix: keyspace, consistency: consistency)
  end

  def has_interface_simple_triggers?(realm_name, object_id) do
    keyspace = Realm.keyspace_name(realm_name)

    simple_triggers_query =
      from SimpleTrigger,
        where: [object_id: ^object_id, object_type: 2]

    consistency = Consistency.domain_model(:read)

    # Repo.some?/2 only returns `{:ok, boolean()}`
    {:ok, result} = Repo.some?(simple_triggers_query, prefix: keyspace, consistency: consistency)
    result
  end

  def any_device_using_interface?(realm_name, interface_name) do
    group_name = "devices-by-interface-#{interface_name}-v0"
    keyspace = Realm.keyspace_name(realm_name)

    devices_query =
      from map in KvStore,
        select: map.key,
        where: [group: ^group_name],
        limit: 1

    consistency = Consistency.domain_model(:read)

    # Repo.some?/2 only returns `{:ok, boolean()}`
    {:ok, result} = Repo.some?(devices_query, prefix: keyspace, consistency: consistency)
    result
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

  @doc """
  Return the list of `Astarte.Core.Interface`s for the specified realm.
  """
  def get_detailed_interfaces_list(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)
    consistency = Consistency.domain_model(:read)
    opts = [prefix: keyspace, consistency: consistency]

    with {:ok, interfaces} <- Repo.fetch_all(Interface, opts),
         {:ok, endpoints} <- Repo.fetch_all(Endpoint, opts) do
      mappings = Enum.map(endpoints, &Mapping.from_db_result!/1)

      mappings_by_interface = mappings |> Enum.group_by(& &1.interface_id)

      interface_documents =
        for interface <- interfaces do
          descriptor = InterfaceDescriptor.from_db_result!(interface)
          mappings = mappings_by_interface |> Map.get(descriptor.interface_id)

          %InterfaceDocument{
            name: descriptor.name,
            description: interface.description,
            doc: interface.doc,
            major_version: descriptor.major_version,
            minor_version: descriptor.minor_version,
            interface_id: descriptor.interface_id,
            type: descriptor.type,
            ownership: descriptor.ownership,
            aggregation: descriptor.aggregation,
            mappings: mappings
          }
        end

      {:ok, interface_documents}
    end
  end
end
