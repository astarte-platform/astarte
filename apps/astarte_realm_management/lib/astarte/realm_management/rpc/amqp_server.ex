defmodule Astarte.RealmManagement.RPC.AMQPServer do
  use Astarte.RPC.AMQPServer,
    queue: Application.fetch_env!(:astarte_realm_management, :rpc_queue),
    amqp_options: Application.get_env(:astarte_realm_management, :amqp_connection, [])
  alias Astarte.RPC.Protocol.RealmManagement.{Call,InstallInterface}

  def process_rpc(payload) do
    case Call.decode(payload) do
      %Call{call: call_tuple} when call_tuple != nil ->
        case call_tuple do
          {:install_interface, %InstallInterface{realm_name: realm_name, interface_json: interface_json}} ->
            Astarte.RealmManagement.Engine.install_interface(realm_name, interface_json)
        invalid_call ->
          Logger.warn "Received unexpected call: " <> inspect invalid_call
          {:error, :unexpected_call}
        end
      invalid_message ->
        Logger.warn "Received unexpected message: " <> inspect invalid_message
        {:error, :unexpected_message}
    end
  end
end

