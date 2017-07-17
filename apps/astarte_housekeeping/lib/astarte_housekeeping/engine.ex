defmodule Astarte.Housekeeping.Engine do
  use GenServer
  require Logger

  @timeout 10000

  def start_link do
    GenServer.start_link(__MODULE__, [], name: :astarte_housekeeping_engine)
  end

  def init(_opts) do
    client = CQEx.Client.new!()
    unless Astarte.Housekeeping.Queries.astarte_keyspace_exists?(client) do
      Logger.info("Astarte keyspace not found, creating it")
      Astarte.Housekeeping.Queries.create_astarte_keyspace(client)
    end
    {:ok, client}
  end

  def create_realm(realm) do
    GenServer.call(:astarte_housekeeping_engine, {:create_realm, realm}, @timeout)
  end

  def realm_exists?(realm) do
    GenServer.call(:astarte_housekeeping_engine, {:realm_exists, realm})
  end

  def handle_call({:create_realm, realm}, _from, client) do
    reply = Astarte.Housekeeping.Queries.create_realm(client, realm)
    {:reply, reply, client}
  end

  def handle_call({:realm_exists, realm}, _from, client) do
    reply = Astarte.Housekeeping.Queries.realm_exists?(client, realm)
    {:reply, reply, client}
  end
end
