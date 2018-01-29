defmodule Astarte.AppEngine.API.Auth do

  alias Astarte.AppEngine.API.Queries
  alias CQEx.Client, as: DatabaseClient

  require Logger

  def fetch_public_key(realm) do
    cass_node = List.first(Application.get_env(:cqerl, :cassandra_nodes))

    with {:ok, client} <- DatabaseClient.new(cass_node, [keyspace: realm]),
         {:ok, public_key} <- Queries.fetch_public_key(client) do

      {:ok, public_key}
    else
      {:error, :public_key_not_found} ->
        Logger.warn("No public key found in realm #{realm}")
        {:error, :public_key_not_found}

      {:error, :shutdown} ->
        Logger.info("Auth request for unexisting realm #{realm}")
        # TODO: random busy wait here to prevent realm enumeration
        {:error, :not_existing_realm}
    end
  end
end
