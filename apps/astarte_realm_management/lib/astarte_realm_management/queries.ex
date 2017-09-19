defmodule Astarte.RealmManagement.Queries do

  require Logger
  alias CQEx.Query, as: DatabaseQuery

  @insert_into_interfaces """
    INSERT INTO interfaces
      (name, major_version, minor_version, interface_id, storage_type, storage, type, quality, flags, source)
      VALUES (:name, :major_version, :minor_version, :interface_id, :storage_type, :storage, :type, :ownership, :aggregation, :source)
  """

  @insert_into_endpoints """
  INSERT INTO endpoints
    (interface_id, endpoint_id, interface_name, interface_major_version, interface_minor_version, interface_type, endpoint, value_type, reliabilty, retention, expiry, allow_unset)
    VALUES (:interface_id, uuid(), :interface_name, :interface_major_version, :interface_minor_version, :interface_type, :endpoint, :value_type, :reliability, :retention, :expiry, :allow_unset)
  """

  @create_individual_multiinterface_table """
    CREATE TABLE IF NOT EXISTS :table_name (
      device_id uuid,
      interface_id uuid,
      endpoint_id uuid,
      path varchar,
      :value_timestamp
      reception_timestamp timestamp,
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
      :columns,

      PRIMARY KEY(device_id, :key_timestamp reception_timestamp)
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

  defp create_interface_table(:individual, :multi, interface_descriptor, _mappings) do
    {suffix, value_timestamp, key_timestamp} = case {interface_descriptor.type, interface_descriptor.explicit_timestamp} do
      {:datastream, true} ->
        {"datastream", "value_timestamp timestamp,", ", value_timestamp, reception_timestamp"}

      {:datastream, false} ->
        {"datastream", "", ", reception_timestamp"}

      {:properties, false} ->
        {"property", "", ""}
    end

    table_name = "individual_#{suffix}"

    create_table_statement = @create_individual_multiinterface_table
      |> String.replace(":table_name", table_name)
      |> String.replace(":value_timestamp", value_timestamp)
      |> String.replace(":key_timestamp", key_timestamp)

    {0, table_name, create_table_statement}
  end

  defp create_interface_table(:individual, :one, interface_descriptor, mappings) do
    table_name = Astarte.Core.CQLUtils.interface_name_to_table_name(interface_descriptor.name, interface_descriptor.major_version)

    mappings_cql = for mapping <- mappings do
        Astarte.Core.CQLUtils.type_to_db_column_name(mapping.value_type) <> " " <> Astarte.Core.CQLUtils.mapping_value_type_to_db_type(mapping.value_type)
    end

    columns = mappings_cql
      |> Enum.uniq
      |> Enum.sort
      |> Enum.join(~s(,\n))

    {value_timestamp, key_timestamp} = case {interface_descriptor.type, interface_descriptor.explicit_timestamp} do
      {:datastream, true} ->
        {"value_timestamp timestamp,", ", value_timestamp, reception_timestamp"}

      {:datastream, false} ->
        {"", ", reception_timestamp"}

      {:properties, false} ->
        {"", ""}
    end

    create_table_statement = @create_interface_table_with_individual_aggregation
    |> String.replace(":interface_name", table_name)
    |> String.replace(":value_timestamp", value_timestamp)
    |> String.replace(":columns", columns)
    |> String.replace(":key_timestamp", key_timestamp)

    {8, table_name, create_table_statement}
  end

  defp create_interface_table(:object, :one, interface_descriptor, mappings) do
    table_name = Astarte.Core.CQLUtils.interface_name_to_table_name(interface_descriptor.name, interface_descriptor.major_version)

    mappings_cql = for mapping <- mappings do
      Astarte.Core.CQLUtils.endpoint_to_db_column_name(mapping.endpoint) <> " " <> Astarte.Core.CQLUtils.mapping_value_type_to_db_type(mapping.value_type)
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

    {9, table_name, create_table_statement}
  end

  def install_new_interface(client, interface_document) do
    table_type = if interface_document.descriptor.aggregation == :individual do
      :multi
    else
      :one
    end

    {storage_type, table_name, create_table_statement} = create_interface_table(interface_document.descriptor.aggregation, table_type, interface_document.descriptor, interface_document.mappings)
    {:ok, _} = DatabaseQuery.call(client, create_table_statement)

    interface_id = Astarte.Core.CQLUtils.interface_id(interface_document.descriptor.name, interface_document.descriptor.major_version)

    query = DatabaseQuery.new
      |> DatabaseQuery.statement(@insert_into_interfaces)
      |> DatabaseQuery.put(:name, interface_document.descriptor.name)
      |> DatabaseQuery.put(:major_version, interface_document.descriptor.major_version)
      |> DatabaseQuery.put(:minor_version, interface_document.descriptor.minor_version)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.put(:storage_type, storage_type)
      |> DatabaseQuery.put(:storage, table_name)
      |> DatabaseQuery.put(:type, Astarte.Core.Interface.Type.to_int(interface_document.descriptor.type))
      |> DatabaseQuery.put(:ownership, Astarte.Core.Interface.Ownership.to_int(interface_document.descriptor.ownership))
      |> DatabaseQuery.put(:aggregation, Astarte.Core.Interface.Aggregation.to_int(interface_document.descriptor.aggregation))
      |> DatabaseQuery.put(:source, interface_document.source)
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

end
