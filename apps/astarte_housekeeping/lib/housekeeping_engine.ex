defmodule Housekeeping.Engine do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: :housekeeping_engine)
  end

  def init(_opts) do
    CQEx.Client.new()
  end

  def process_rpc(message) do
    GenServer.call(:housekeeping_engine, {:process_rpc, message})
  end

  def handle_call({:process_rpc, message}, _from, client) do
    %Housekeeping.RPC.Call{call: call_tuple} = Housekeeping.RPC.Call.decode(message)
    reply =
      case call_tuple do
        {:create_realm, %Housekeeping.RPC.CreateRealm{realm: realm}} ->
          Housekeeping.Queries.create_realm(client, realm)
      end
    {:reply, reply, client}
  end
end
