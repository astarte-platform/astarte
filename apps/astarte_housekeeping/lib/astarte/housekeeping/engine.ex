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

  def process_rpc(message) do
    GenServer.call(:astarte_housekeeping_engine, {:process_rpc, message}, @timeout)
  end

  def handle_call({:process_rpc, message}, _from, client) do
    reply =
      case Astarte.RPC.Protocol.Housekeeping.Call.decode(message) do
        %Astarte.RPC.Protocol.Housekeeping.Call{call: call_tuple} when call_tuple != nil ->
          case call_tuple do
            {:create_realm, %Astarte.RPC.Protocol.Housekeeping.CreateRealm{realm: realm}} ->
              Astarte.Housekeeping.Queries.create_realm(client, realm)
            _ ->
              Logger.warn "Received unexpected call: " <> inspect call_tuple
              {:error, :unexpected_call}
          end
        _ ->
          Logger.warn "Received unexpected message: " <> inspect message
          {:error, :unexpected_message}
      end
    {:reply, reply, client}
  end
end
