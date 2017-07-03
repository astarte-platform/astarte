defmodule Astarte.RealmManagement.Engine do
  require Logger
  alias CQEx.Client, as: DatabaseClient

  def install_interface(realm_name, interface_json) do
    interface_document = Astarte.Core.InterfaceDocument.from_json(interface_json)

    client = DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

    unless Astarte.RealmManagement.Queries.is_interface_major_available?(client, interface_document.descriptor.name, interface_document.descriptor.major_version) do
      Astarte.RealmManagement.Queries.install_new_interface(client, interface_document)
    else
      {:error, :already_installed_interface}
    end
  end

  def interface_source(realm_name, interface_name, interface_major_version) do
    client = DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

    Astarte.RealmManagement.Queries.interface_source(client, interface_name, interface_major_version)
  end

  def list_interface_versions(realm_name, interface_name) do
    client = DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

    Astarte.RealmManagement.Queries.interface_available_versions(client, interface_name)
  end

end
