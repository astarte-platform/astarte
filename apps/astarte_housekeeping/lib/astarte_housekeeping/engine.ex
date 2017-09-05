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

  def create_realm(realm, opts \\ []) do
    if opts[:async] do
      GenServer.cast(:astarte_housekeeping_engine, {:create_realm, realm})
    else
      GenServer.call(:astarte_housekeeping_engine, {:create_realm, realm}, @timeout)
    end
  end

  def realm_exists?(realm) do
    GenServer.call(:astarte_housekeeping_engine, {:realm_exists, realm})
  end

  def realms_list() do
    GenServer.call(:astarte_housekeeping_engine, {:realms_list})
  end

  def get_realm(realm) do
    GenServer.call(:astarte_housekeeping_engine, {:get_realm, realm})
  end

  def handle_cast({:create_realm, realm}, client) do
    Astarte.Housekeeping.Queries.create_realm(client, realm)
    {:noreply, client}
  end

  def handle_call({:create_realm, realm}, _from, client) do
    reply = Astarte.Housekeeping.Queries.create_realm(client, realm)
    {:reply, reply, client}
  end

  def handle_call({:realm_exists, realm}, _from, client) do
    reply = Astarte.Housekeeping.Queries.realm_exists?(client, realm)
    {:reply, reply, client}
  end

  def handle_call({:realms_list}, _from, client) do
    reply = Astarte.Housekeeping.Queries.realms_list(client)
    {:reply, reply, client}
  end

  def handle_call({:get_realm, realm}, _from, client) do
    reply = Astarte.Housekeeping.Queries.get_realm(client, realm)
    {:reply, reply, client}
  end
end
