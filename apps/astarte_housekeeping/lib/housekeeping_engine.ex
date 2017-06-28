defmodule Housekeeping.Engine do
  use GenServer

  @timeout 10000

  def start_link do
    GenServer.start_link(__MODULE__, [], name: :housekeeping_engine)
  end

  def init(_opts) do
    CQEx.Client.new()
  end

  def process_rpc(message) do
    GenServer.call(:housekeeping_engine, {:process_rpc, message}, @timeout)
  end

  def handle_call({:process_rpc, message}, _from, client) do
    %Astarte.RPC.Protocol.Housekeeping.Call{call: call_tuple} = Astarte.RPC.Protocol.Housekeeping.Call.decode(message)
    reply =
      case call_tuple do
        {:create_realm, %Astarte.RPC.Protocol.Housekeeping.CreateRealm{realm: realm}} ->
          Housekeeping.Queries.create_realm(client, realm)
      end
    {:reply, reply, client}
  end
end
