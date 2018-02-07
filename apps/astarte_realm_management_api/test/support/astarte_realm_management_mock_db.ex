defmodule Astarte.RealmManagement.Mock.DB do
  alias Astarte.RealmManagement.API.JWTTestHelper

  def start_link do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def get_interfaces_list(realm) do
    Agent.get(__MODULE__, &Map.get(&1, "interfaces_#{realm}", []))
  end

  def get_jwt_public_key_pem(realm) do
    Agent.get(__MODULE__, &Map.get(&1, "jwt_public_key_pem_#{realm}"))
  end

  def put_jwt_public_key_pem(realm, jwt_public_key_pem) do
    Agent.update(__MODULE__, &Map.put(&1, "jwt_public_key_pem_#{realm}", jwt_public_key_pem))
  end
end
