defmodule Astarte.Housekeeping.RPC.AMQPServer do
  use Astarte.RPC.AMQPServer,
    queue: Application.fetch_env!(:astarte_housekeeping, :rpc_queue),
    amqp_options: Application.get_env(:astarte_housekeeping, :amqp_connection, [])
  use Astarte.RPC.Protocol.Housekeeping

  def process_rpc(payload) do
    process_decoded_call(Call.decode(payload))
  end

  defp process_decoded_call(%Call{call: nil}) do
    Logger.warn "Received empty call"
    {:error, :empty_call}
  end

  defp process_decoded_call(%Call{call: call_tuple}) do
    process_call_tuple(call_tuple)
  end

  defp process_call_tuple({:create_realm, %CreateRealm{realm: nil}}) do
    Logger.warn "CreateRealm with realm == nil"
    {:error, :invalid_argument}
  end

  defp process_call_tuple({:create_realm, %CreateRealm{realm: realm}}) do
    Astarte.Housekeeping.Engine.create_realm(realm)
  end

  defp process_call_tuple({:does_realm_exist, %DoesRealmExist{realm: realm}}) do
    exists = Astarte.Housekeeping.Engine.realm_exists?(realm)

    %DoesRealmExistReply{exists: exists}
    |> encode_reply(:does_realm_exist_reply)
    |> ok_wrap
  end

  defp encode_reply(reply, reply_type) do
    %Reply{reply: {reply_type, reply}}
    |> Reply.encode
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
