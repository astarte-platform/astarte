#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017-2018 Ispirata Srl
#

defmodule Astarte.Housekeeping.RPC.Handler do
  @behaviour Astarte.RPC.Handler

  alias Astarte.RPC.Protocol.Housekeeping.{
    Call,
    CreateRealm,
    DoesRealmExist,
    DoesRealmExistReply,
    GenericErrorReply,
    GenericOkReply,
    GetRealm,
    GetRealmReply,
    GetRealmsList,
    GetRealmsListReply,
    Reply
  }

  require Logger

  def handle_rpc(payload) do
    with {:ok, call_tuple} <- extract_call_tuple(Call.decode(payload)) do
      call_rpc(call_tuple)
    end
  end

  defp extract_call_tuple(%Call{call: nil}) do
    Logger.warn("Received empty call")
    {:error, :empty_call}
  end

  defp extract_call_tuple(%Call{call: call_tuple}) do
    {:ok, call_tuple}
  end

  defp call_rpc({:create_realm, %CreateRealm{realm: nil}}) do
    Logger.warn("CreateRealm with realm == nil")
    generic_error(:empty_name, "empty realm name")
  end

  defp call_rpc({:create_realm, %CreateRealm{jwt_public_key_pem: nil}}) do
    Logger.warn("CreateRealm with jwt_public_key_pem == nil")
    generic_error(:empty_public_key, "empty jwt public key pem")
  end

  defp call_rpc(
         {:create_realm,
          %CreateRealm{
            realm: realm,
            jwt_public_key_pem: pub_key,
            replication_factor: replication,
            async_operation: async
          }}
       ) do
    if Astarte.Housekeeping.Engine.realm_exists?(realm) do
      generic_error(:existing_realm, "realm already exists")
    else
      case Astarte.Housekeeping.Engine.create_realm(realm, pub_key, replication, async: async) do
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
      %{realm_name: realm_name_reply, jwt_public_key_pem: public_key} ->
        %GetRealmReply{realm_name: realm_name_reply, jwt_public_key_pem: public_key}
        |> encode_reply(:get_realm_reply)
        |> ok_wrap

      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp generic_error(
         error_name,
         user_readable_message \\ nil,
         user_readable_error_name \\ nil,
         error_data \\ nil
       ) do
    %GenericErrorReply{
      error_name: to_string(error_name),
      user_readable_message: user_readable_message,
      user_readable_error_name: user_readable_error_name,
      error_data: error_data
    }
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
    |> Reply.encode()
  end

  defp encode_reply(reply, reply_type) do
    %Reply{reply: {reply_type, reply}}
    |> Reply.encode()
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
