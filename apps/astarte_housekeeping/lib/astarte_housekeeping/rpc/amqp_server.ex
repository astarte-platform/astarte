defmodule Astarte.Housekeeping.RPC.AMQPServer do
  use Astarte.RPC.AMQPServer,
    queue: Application.fetch_env!(:astarte_housekeeping, :rpc_queue),
    amqp_options: Application.get_env(:astarte_housekeeping, :amqp_connection, [])
  use Astarte.RPC.Protocol.Housekeeping

  def process_rpc(payload) do
    with {:ok, call_tuple} <- extract_call_tuple(Call.decode(payload)) do
      call_rpc(call_tuple)
    end
  end

  defp extract_call_tuple(%Call{call: nil}) do
    Logger.warn "Received empty call"
    {:error, :empty_call}
  end

  defp extract_call_tuple(%Call{call: call_tuple}) do
    {:ok, call_tuple}
  end

  defp call_rpc({:create_realm, %CreateRealm{realm: nil}}) do
    Logger.warn "CreateRealm with realm == nil"
    generic_error(:empty_name, "empty realm name")
  end

  defp call_rpc({:create_realm, %CreateRealm{realm: realm, async_operation: async}}) do
    if Astarte.Housekeeping.Engine.realm_exists?(realm) do
      generic_error(:existing_realm, "realm already exists")
    else
      case Astarte.Housekeeping.Engine.create_realm(realm, async: async) do
        {:error, reason} -> generic_error(reason)
        :ok -> generic_ok(async)
      end
    end
  end

  defp call_rpc({:does_realm_exist, %DoesRealmExist{realm: realm}}) do
    exists = Astarte.Housekeeping.Engine.realm_exists?(realm)

    %DoesRealmExistReply{exists: exists}
    |> encode_reply(:does_realm_exist_reply)
    |> ok_wrap
  end

  defp call_rpc({:get_realms_list, %GetRealmsList{}}) do
    list = Astarte.Housekeeping.Engine.realms_list()

    %GetRealmsListReply{realms_names: list}
    |> encode_reply(:get_realms_list_reply)
    |> ok_wrap
  end

  defp call_rpc({:get_realm, %GetRealm{realm_name: realm_name}}) do
    case Astarte.Housekeeping.Engine.get_realm(realm_name) do
      %{realm_name: realm_name_reply} ->
        %GetRealmReply{realm_name: realm_name_reply}
        |> encode_reply(:get_realm_reply)
        |> ok_wrap

      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp generic_error(error_name, user_readable_message \\ nil, user_readable_error_name \\ nil, error_data \\ nil) do
    %GenericErrorReply{error_name: to_string(error_name),
                       user_readable_message: user_readable_message,
                       user_readable_error_name: user_readable_error_name,
                       error_data: error_data}
    |> encode_reply(:generic_error_reply)
    |> ok_wrap
  end

  defp generic_ok(async) do
    %GenericOkReply{async_operation: async}
    |> encode_reply(:generic_ok_reply)
    |> ok_wrap
  end

  defp encode_reply(%GenericErrorReply{} = reply, _reply_type) do
    %Reply{reply: {:generic_error_reply, reply}, error: true}
    |> Reply.encode
  end

  defp encode_reply(reply, reply_type) do
    %Reply{reply: {reply_type, reply}}
    |> Reply.encode
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
