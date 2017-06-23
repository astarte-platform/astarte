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

  def connect_to_local_realm(realm) do
    {:ok, client} = CQEx.Client.new({"127.0.0.1", 9042}, [keyspace: realm])
    client
  end

  def install_new_interface(client, interface_document) do
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
