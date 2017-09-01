defmodule Astarte.Housekeeping.API.Realms.RPC.AMQPClient do
  use Astarte.RPC.AMQPClient,
    rpc_queue: Application.fetch_env!(:astarte_housekeeping_api, :rpc_queue),
    amqp_options: Application.get_env(:astarte_housekeeping_api, :amqp_connection, [])

  use Astarte.RPC.Protocol.Housekeeping
  alias Astarte.Housekeeping.API.Realms.Realm

  def create_realm(realm = %Realm{realm_name: realm_name}) do
    %CreateRealm{realm: realm_name}
    |> encode_call(:create_realm)
    |> rpc_cast()

    {:ok, realm}
  end

  defp realm_exists?(realm_name) do
    %DoesRealmExist{realm: realm_name}
    |> encode_call(:does_realm_exist)
    |> rpc_call()
    |> decode_reply()
    |> extract_reply()
  end

  defp encode_call(call, callname) do
    %Call{call: {callname, call}}
    |> Call.encode()
  end

  defp decode_reply({:ok, encoded_reply}) when is_binary(encoded_reply) do
    %Reply{reply: reply} = Reply.decode(encoded_reply)
    reply
  end

  defp extract_reply({:does_realm_exist_reply, %DoesRealmExistReply{exists: exists}}) do
    exists
  end

  defp extract_reply({:generic_error_reply, error_struct = %GenericErrorReply{}}) do
    {:error, Map.from_struct(error_struct)}
  end

  defp extract_reply({:generic_ok_reply, %GenericOkReply{async_operation: async}}) do
    if async do
      {:ok, :started}
    else
      :ok
    end
  end
end
