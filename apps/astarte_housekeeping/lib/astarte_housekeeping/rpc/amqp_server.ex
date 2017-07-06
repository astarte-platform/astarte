defmodule Astarte.Housekeeping.RPC.AMQPServer do
  use Astarte.RPC.AMQPServer,
    queue: Application.fetch_env!(:astarte_housekeeping, :rpc_queue),
    amqp_options: Application.get_env(:astarte_housekeeping, :amqp_connection, [])
  alias Astarte.RPC.Protocol.Housekeeping.{Call,CreateRealm}

  def process_rpc(payload) do
    case Call.decode(payload) do
      %Call{call: call_tuple} when call_tuple != nil ->
        case call_tuple do
          {:create_realm, %CreateRealm{realm: realm}} ->
            Astarte.Housekeeping.Engine.create_realm(realm)
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
