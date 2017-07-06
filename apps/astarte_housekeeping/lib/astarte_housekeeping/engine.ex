defmodule Astarte.Housekeeping.Engine do
  use GenServer
  require Logger

  @timeout 10000

  def start_link do
    GenServer.start_link(__MODULE__, [], name: :astarte_housekeeping_engine)
  end

  def init(_opts) do
    CQEx.Client.new()
  end

  def create_realm(realm) do
    GenServer.call(:astarte_housekeeping_engine, {:create_realm, realm}, @timeout)
  end

  def handle_call({:create_realm, realm}, _from, client) do
    reply = Astarte.Housekeeping.Queries.create_realm(client, realm)
    {:reply, reply, client}
  end
end
