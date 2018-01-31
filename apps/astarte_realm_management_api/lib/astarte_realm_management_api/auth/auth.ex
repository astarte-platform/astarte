defmodule Astarte.RealmManagement.API.Auth do
  alias Astarte.RealmManagement.API.RPC.AMQPClient

  require Logger

  def fetch_public_key(realm) do
    AMQPClient.get_jwt_public_key_pem(realm)
  end
end
