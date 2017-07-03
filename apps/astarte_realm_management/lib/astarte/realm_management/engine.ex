defmodule Astarte.RealmManagement.Engine do
  require Logger
  alias CQEx.Client, as: DatabaseClient

  def install_interface(realm_name, interface_json) do
    interface_document = Astarte.Core.InterfaceDocument.from_json(interface_json)

    DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])
    |> Astarte.RealmManagement.Queries.install_new_interface(interface_document)
  end

end
