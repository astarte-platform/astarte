defmodule Astarte.Housekeeping.RPC.AMQPServer do
  use Astarte.RPC.AMQPServer,
    queue: Application.fetch_env!(:astarte_housekeeping, :rpc_queue),
    amqp_options: Application.get_env(:astarte_housekeeping, :amqp_connection, [])
  alias Astarte.RPC.Protocol.Housekeeping.{Call,CreateRealm}

  def process_rpc(payload) do
    process_decoded_call(Call.decode(payload))
  end

  defp process_decoded_call(%Call{call: call_tuple}) when call_tuple != nil do
    process_call_tuple(call_tuple)
  end

  defp process_decoded_call(invalid_message) do
    Logger.warn "Received unexpected message: " <> inspect invalid_message
    {:error, :unexpected_message}
  end

  defp process_call_tuple({:create_realm, %CreateRealm{realm: realm}}) do
    Astarte.Housekeeping.Engine.create_realm(realm)
  end

  defp process_call_tuple(invalid_call) do
    Logger.warn "Received unexpected call: " <> inspect invalid_call
    {:error, :unexpected_call}
  end
end
