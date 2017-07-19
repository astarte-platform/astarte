defmodule Astarte.Housekeeping.Mock do
  use Astarte.RPC.AMQPServer,
    queue: Application.fetch_env!(:astarte_housekeeping_api, :rpc_queue),
    amqp_options: Application.get_env(:astarte_housekeeping_api, :amqp_connection, [])

  use Astarte.RPC.Protocol.Housekeeping

  alias Astarte.Housekeeping.API.Realms.Realm

  def process_rpc(payload) do
    extract_call_tuple(Call.decode(payload))
    |> execute_rpc()
  end

  defp extract_call_tuple(%Call{call: call_tuple}) do
    call_tuple
  end

  defp execute_rpc({:create_realm, %CreateRealm{realm: realm}}) do
    Astarte.Housekeeping.Mock.DB.put_realm(%Realm{realm_name: realm})
  end

  defp execute_rpc({:does_realm_exist, %DoesRealmExist{realm: realm}}) do
    exists = Astarte.Housekeeping.Mock.DB.realm_exists?(realm)

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
