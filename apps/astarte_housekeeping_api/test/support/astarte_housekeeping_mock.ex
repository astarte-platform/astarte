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
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.Housekeeping.Mock do
  use Astarte.RPC.AMQPServer

  use Astarte.RPC.Protocol.Housekeeping

  alias Astarte.Housekeeping.API.Realms.Realm

  def process_rpc(payload) do
    extract_call_tuple(Call.decode(payload))
    |> execute_rpc()
  end

  defp extract_call_tuple(%Call{call: call_tuple}) do
    call_tuple
  end

  defp execute_rpc({:create_realm, %CreateRealm{realm: realm, async_operation: async, jwt_public_key_pem: pem}}) do
    Astarte.Housekeeping.Mock.DB.put_realm(%Realm{realm_name: realm, jwt_public_key_pem: pem})

    %GenericOkReply{async_operation: async}
    |> encode_reply(:generic_ok_reply)
    |> ok_wrap
  end

  defp execute_rpc({:does_realm_exist, %DoesRealmExist{realm: realm}}) do
    exists = Astarte.Housekeeping.Mock.DB.realm_exists?(realm)

    %DoesRealmExistReply{exists: exists}
    |> encode_reply(:does_realm_exist_reply)
    |> ok_wrap
  end

  defp execute_rpc({:get_realms_list, %GetRealmsList{}}) do
    list = Astarte.Housekeeping.Mock.DB.realms_list

    %GetRealmsListReply{realms_names: list}
    |> encode_reply(:get_realms_list_reply)
    |> ok_wrap
  end

  defp execute_rpc({:get_realm, %GetRealm{realm_name: realm_name}}) do
    case Astarte.Housekeeping.Mock.DB.get_realm(realm_name) do
      nil ->
        generic_error(:realm_not_found)
      %Realm{realm_name: ^realm_name, jwt_public_key_pem: pem} ->
        %GetRealmReply{realm_name: realm_name, jwt_public_key_pem: pem}
        |> encode_reply(:get_realm_reply)
    end
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
