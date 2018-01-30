defmodule Astarte.Housekeeping.Mock.DB do
  alias Astarte.Housekeeping.API.Realms.Realm

  def start_link do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put_realm(realm = %Realm{realm_name: realm_name, jwt_public_key_pem: _pem}) do
    Agent.update(__MODULE__, &Map.put(&1, realm_name, realm))
  end

  def get_realm(realm_name) do
    Agent.get(__MODULE__, &Map.get(&1, realm_name))
  end

  def realm_exists?(realm_name) do
    Agent.get(__MODULE__, &Map.has_key?(&1, realm_name))
  end

  def realms_list do
    Agent.get(__MODULE__, &Map.keys(&1))
  end
end
