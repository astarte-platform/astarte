defmodule Astarte.RealmManagement.Queries do

  require Logger
  alias CQEx.Query, as: DatabaseQuery

  @insert_into_interfaces """
    INSERT INTO interfaces
      (name, major_version, minor_version, type, quality, flags, source)
      VALUES (:name, :major_version, :minor_version, :type, :ownership, :aggregation, :source)
  """

  @insert_into_endpoints """
  INSERT INTO endpoints
    (endpoint_id, interface_name, interface_major_version, interface_minor_version, interface_type, endpoint, value_type, reliabilty, retention, expiry, allow_unset)
    VALUES (uuid(), :interface_name, :interface_major_version, :interface_minor_version, :interface_type, :endpoint, :value_type, :reliability, :retention, :expiry, :allow_unset)
  """
  @create_interface_table_with_individual_aggregation """
    CREATE TABLE :interface_name (
      device_id uuid,
      endpoint_id uuid,
      path varchar,
      reception_timestamp timestamp,
      endpoint_tokens list<varchar>,
      :columns,
      PRIMARY KEY(device_id, endpoint_id, path)
    )
  """

  @create_interface_table_with_object_aggregation """
    CREATE TABLE :interface_name (
      device_id uuid,
      reception_timestamp timestamp,
      :columns,
      PRIMARY KEY(device_id, reception_timestamp)
    )
  """

  @delete_endpoint_from_endpoints """
     DELETE FROM endpoints WHERE endpoint_id=:endpoint_id;
  """

  @delete_interface_from_interfaces """
     DELETE FROM interfaces WHERE name=:name;
  """

  @drop_interface_table """
     DROP TABLE :table_name;
  """

  # TODO: ALLOW FILTERING is not supported on Scylla DB right now
  # https://github.com/scylladb/scylla/labels/cassandra%203.x%20compatibility
  @query_interface_endpoints_with_major_0 """
    SELECT endpoint_id FROM endpoints WHERE interface_name=:name AND interface_major_version=0 ALLOW FILTERING;
  """

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

  defp create_interface_table(:individual, interface_descriptor, mappings) do
    table_name = Astarte.Core.CQLUtils.interface_name_to_table_name(interface_descriptor.name, interface_descriptor.major_version)

    mappings_cql = for mapping <- mappings do
        Astarte.Core.CQLUtils.type_to_db_column_name(mapping.value_type) <> " " <> Astarte.Core.CQLUtils.mapping_value_type_to_db_type(mapping.value_type)
    end

    columns = mappings_cql
      |> Enum.uniq
      |> Enum.sort
      |> Enum.join(~s(,\n))

    create_table_statement = @create_interface_table_with_individual_aggregation
    |> String.replace(":interface_name", table_name)
    |> String.replace(":columns", columns)

    create_table_statement
  end

  defp create_interface_table(:object, interface_descriptor, mappings) do
    table_name = Astarte.Core.CQLUtils.interface_name_to_table_name(interface_descriptor.name, interface_descriptor.major_version)

    mappings_cql = for mapping <- mappings do
      Astarte.Core.CQLUtils.endpoint_to_db_column_name(mapping.endpoint) <> " " <> Astarte.Core.CQLUtils.mapping_value_type_to_db_type(mapping.value_type)
    end

    columns = mappings_cql
      |> Enum.join(~s(,\n))

    create_table_statement = @create_interface_table_with_object_aggregation
      |> String.replace(":interface_name", table_name)
      |> String.replace(":columns", columns)

    create_table_statement
  end

  def install_new_interface(client, interface_document) do
    {:ok, _} = DatabaseQuery.call(client, create_interface_table(interface_document.descriptor.aggregation, interface_document.descriptor, interface_document.mappings))

    query = DatabaseQuery.new
      |> DatabaseQuery.statement(@insert_into_interfaces)
      |> DatabaseQuery.put(:name, interface_document.descriptor.name)
      |> DatabaseQuery.put(:major_version, interface_document.descriptor.major_version)
      |> DatabaseQuery.put(:minor_version, interface_document.descriptor.minor_version)
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
    Logger.warn "update_interface: " <> inspect(interface_document)
    Logger.warn "client: " <> inspect(client)
    {:error, :not_implemented}
  end

  def delete_interface(client, interface_name, interface_major_version) do
    if interface_major_version != 0 do
      {:error, :forbidden}

    else
      Logger.warn "delete interface: " <> interface_name

      query = DatabaseQuery.new
        |> DatabaseQuery.statement(@delete_interface_from_interfaces)
        |> DatabaseQuery.put(:name, interface_name)
      DatabaseQuery.call!(client, query)

      query = DatabaseQuery.new
        |> DatabaseQuery.statement(@query_interface_endpoints_with_major_0)
        |> DatabaseQuery.put(:name, interface_name)
      endpoints_to_delete = DatabaseQuery.call!(client, query)
        |> Enum.to_list

      Enum.each(endpoints_to_delete, fn(endpoint) ->
        delete_query = DatabaseQuery.new
          |> DatabaseQuery.statement(@delete_endpoint_from_endpoints)
          |> DatabaseQuery.put(:endpoint_id, endpoint[:endpoint_id])
        DatabaseQuery.call!(client, delete_query)
      end)

      drop_table_statement = @drop_interface_table
        |> String.replace(":table_name", Astarte.Core.CQLUtils.interface_name_to_table_name(interface_name, 0))
      DatabaseQuery.call!(client, drop_table_statement)

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
