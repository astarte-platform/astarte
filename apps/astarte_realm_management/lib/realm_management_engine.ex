defmodule Astarte.RealmManagement.Engine do
  use GenServer
  require Logger

  @timeout 10000

  def start_link do
    GenServer.start_link(__MODULE__, [], name: :astarte_realm_management_engine)
  end

  def init(_opts) do
    CQEx.Client.new()
  end

  def process_rpc(message) do
    GenServer.call(:astarte_realm_management_engine, {:process_rpc, message}, @timeout)
  end

  def handle_call({:process_rpc, message}, _from, client) do
    reply =
      case Astarte.RPC.Protocol.RealmManagement.Call.decode(message) do
        %Astarte.RPC.Protocol.RealmManagement.Call{call: call_tuple} when call_tuple != nil ->
          case call_tuple do
            {:install_interface, %Astarte.RPC.Protocol.RealmManagement.InstallInterface{interface_json: interface_json}} ->
              Astarte.RealmManagement.Queries.install_new_interface(client, interface_json)
          _ ->
            Logger.warn "Received unexpected call: " <> inspect call_tuple
            {:error, :unexpected_call}
          end
        _ ->
          Logger.warn "Received unexpected message: " <> inspect message
          {:error, :unexpected_messsage}
      end
    {:reply, reply, client}
  end
end
