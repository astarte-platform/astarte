defmodule Astarte.AppEngine.API.Auth do

  alias Astarte.AppEngine.API.Queries
  alias CQEx.Client, as: DatabaseClient

  def fetch_public_key(realm) do
    cass_node = List.first(Application.get_env(:cqerl, :cassandra_nodes))

    case DatabaseClient.new(cass_node, [keyspace: realm]) do
      {:ok, client} ->
        Queries.fetch_public_key(client)
      _ ->
        {:error, :not_existing_realm}
    end
  end
end
