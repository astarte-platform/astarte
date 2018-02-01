defmodule Astarte.RealmManagement.Mock do
  use Astarte.RPC.AMQPServer

  use Astarte.RPC.Protocol.RealmManagement

  alias Astarte.RealmManagement.API.Realms.Realm
  alias Astarte.RealmManagement.Mock.DB

  def process_rpc(payload) do
    extract_call_tuple(Call.decode(payload))
    |> execute_rpc()
  end

  defp extract_call_tuple(%Call{call: call_tuple}) do
    call_tuple
  end

  defp execute_rpc({:get_interfaces_list, %GetInterfacesList{realm_name: realm_name}}) do
    list = DB.interfaces_list(realm_name)

    %GetInterfacesListReply{interfaces_names: list}
    |> encode_reply(:get_interfaces_list_reply)
    |> ok_wrap
  end

  defp execute_rpc({:get_jwt_public_key_pem, %GetJWTPublicKeyPEM{realm_name: realm_name}}) do
    pem = DB.jwt_public_key_pem(realm_name)

    %GetJWTPublicKeyPEMReply{jwt_public_key_pem: pem}
    |> encode_reply(:get_jwt_public_key_pem_reply)
    |> ok_wrap
  end

  defp generic_error(error_name) do
    %GenericErrorReply{error_name: to_string(error_name)}
    |> encode_reply(:generic_error_reply)
  end

  defp encode_reply(reply, reply_type) do
    %Reply{reply: {reply_type, reply}}
    |> Reply.encode
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
