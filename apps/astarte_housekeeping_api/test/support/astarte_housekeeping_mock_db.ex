defmodule Astarte.Housekeeping.Mock.DB do
  alias Astarte.Housekeeping.API.Realms.Realm

  def start_link do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put_realm(realm = %Realm{realm_name: realm_name}) do
    Agent.update(__MODULE__, &Map.put(&1, realm_name, realm))
  end

  def get_realm(realm_name) do
    Agent.get(__MODULE__, &Map.fetch!(&1, realm_name))
  end

  def realm_exists?(realm_name) do
    Agent.get(__MODULE__, &Map.has_key?(&1, realm_name))
  end
end
