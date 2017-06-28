defmodule RealmManagement.Queries do

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

  def connect_to_local_realm(realm) do
    {:ok, client} = CQEx.Client.new({"127.0.0.1", 9042}, [keyspace: realm])
    client
  end

  defp create_interface_table(:individual, interface_name, mappings) do
    mappings_cql = for mapping <- mappings do
        AstarteCore.CQLUtils.type_to_db_column_name(mapping.value_type) <> " " <> AstarteCore.CQLUtils.mapping_value_type_to_db_type(mapping.value_type)
    end

    columns = mappings_cql
      |> Enum.uniq
      |> Enum.sort
      |> Enum.join(~s(,\n))

    create_table_statement = @create_interface_table_with_individual_aggregation
    |> String.replace(":interface_name", interface_name)
    |> String.replace(":columns", columns)

    create_table_statement
  end

  defp create_interface_table(:object, interface_name, mappings) do
    mappings_cql = for mapping <- mappings do
      AstarteCore.CQLUtils.endpoint_to_db_column_name(mapping.endpoint) <> " " <> AstarteCore.CQLUtils.mapping_value_type_to_db_type(mapping.value_type)
    end

    columns = mappings_cql
      |> Enum.join(~s(,\n))

    create_table_statement = @create_interface_table_with_object_aggregation
      |> String.replace(":interface_name", interface_name)
      |> String.replace(":columns", columns)

    create_table_statement
  end

  def install_new_interface(client, interface_document) do
    table_name = AstarteCore.CQLUtils.interface_name_to_table_name(interface_document.descriptor.name, interface_document.descriptor.major_version)
    {:ok, _} = DatabaseQuery.call(client, create_interface_table(interface_document.descriptor.aggregation, table_name, interface_document.mappings))

    query = DatabaseQuery.new
      |> DatabaseQuery.statement(@insert_into_interfaces)
      |> DatabaseQuery.put(:name, interface_document.descriptor.name)
      |> DatabaseQuery.put(:major_version, interface_document.descriptor.major_version)
      |> DatabaseQuery.put(:minor_version, interface_document.descriptor.minor_version)
      |> DatabaseQuery.put(:type, AstarteCore.Interface.Type.to_int(interface_document.descriptor.type))
      |> DatabaseQuery.put(:ownership, AstarteCore.Interface.Ownership.to_int(interface_document.descriptor.ownership))
      |> DatabaseQuery.put(:aggregation, AstarteCore.Interface.Aggregation.to_int(interface_document.descriptor.aggregation))
      |> DatabaseQuery.put(:source, interface_document.source)
    {:ok, _} = DatabaseQuery.call(client, query)

    base_query = DatabaseQuery.new
      |> DatabaseQuery.statement(@insert_into_endpoints)
      |> DatabaseQuery.put(:interface_name, interface_document.descriptor.name)
      |> DatabaseQuery.put(:interface_major_version, interface_document.descriptor.major_version)
      |> DatabaseQuery.put(:interface_minor_version, interface_document.descriptor.minor_version)
      |> DatabaseQuery.put(:interface_type, AstarteCore.Interface.Type.to_int(interface_document.descriptor.type))

    for mapping <- interface_document.mappings do
      query = base_query
        |> DatabaseQuery.put(:endpoint, mapping.endpoint)
        |> DatabaseQuery.put(:value_type, AstarteCore.Mapping.ValueType.to_int(mapping.value_type))
        |> DatabaseQuery.put(:reliability, AstarteCore.Mapping.Reliability.to_int(mapping.reliability))
        |> DatabaseQuery.put(:retention, AstarteCore.Mapping.Retention.to_int(mapping.retention))
        |> DatabaseQuery.put(:expiry, mapping.expiry)
        |> DatabaseQuery.put(:allow_unset, mapping.allow_unset)
      {:ok, _} = DatabaseQuery.call(client, query)
    end

    :ok
  end

end
