#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.Housekeeping.Mock do
  alias Astarte.RPC.Protocol.Housekeeping.{
    Call,
    CreateRealm,
    DeleteRealm,
    DoesRealmExist,
    DoesRealmExistReply,
    GenericErrorReply,
    GenericOkReply,
    GetRealm,
    GetRealmReply,
    GetRealmsList,
    GetRealmsListReply,
    Reply,
    UpdateRealm,
    SetLimit,
    RemoveLimit
  }

  alias Astarte.Housekeeping.API.Realms.Realm

  def rpc_call(payload, _destination) do
    handle_rpc(payload)
  end

  def handle_rpc(payload) do
    extract_call_tuple(Call.decode(payload))
    |> execute_rpc()
  end

  defp extract_call_tuple(%Call{call: call_tuple}) do
    call_tuple
  end

  defp execute_rpc(
         {:create_realm,
          %CreateRealm{
            realm: realm,
            async_operation: async,
            jwt_public_key_pem: pem,
            replication_factor: rep,
            replication_class: class,
            datacenter_replication_factors: dc_repl,
            device_registration_limit: dev_reg_limit
          }}
       ) do
    Astarte.Housekeeping.Mock.DB.put_realm(%Realm{
      realm_name: realm,
      jwt_public_key_pem: pem,
      replication_factor: rep,
      replication_class: class,
      datacenter_replication_factors: dc_repl,
      device_registration_limit: dev_reg_limit
    })

    %GenericOkReply{async_operation: async}
    |> encode_reply(:generic_ok_reply)
    |> ok_wrap
  end

  defp execute_rpc(
         {:update_realm,
          %UpdateRealm{
            realm: realm_name,
            jwt_public_key_pem: pem,
            replication_factor: rep,
            replication_class: class,
            datacenter_replication_factors: dc_repl,
            device_registration_limit: dev_reg_limit
          }}
       ) do
    # This is backend logic
    limit =
      case dev_reg_limit do
        nil ->
          %Realm{} = realm = Astarte.Housekeeping.Mock.DB.get_realm(realm_name)
          realm.device_registration_limit

        {:set_limit, %SetLimit{value: n}} ->
          n

        {:remove_limit, %RemoveLimit{}} ->
          nil
      end

    Astarte.Housekeeping.Mock.DB.put_realm(%Realm{
      realm_name: realm_name,
      jwt_public_key_pem: pem,
      replication_factor: rep,
      replication_class: class,
      datacenter_replication_factors: dc_repl,
      device_registration_limit: limit
    })

    %GetRealmReply{
      realm_name: realm_name,
      jwt_public_key_pem: pem,
      replication_factor: rep,
      replication_class: class,
      datacenter_replication_factors: dc_repl,
      device_registration_limit: limit
    }
    |> encode_reply(:get_realm_reply)
    |> ok_wrap
  end

  defp execute_rpc({:delete_realm, %DeleteRealm{realm: realm, async_operation: async}}) do
    Astarte.Housekeeping.Mock.DB.delete_realm(realm)

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
    list = Astarte.Housekeeping.Mock.DB.realms_list()

    %GetRealmsListReply{realms_names: list}
    |> encode_reply(:get_realms_list_reply)
    |> ok_wrap
  end

  defp execute_rpc({:get_realm, %GetRealm{realm_name: realm_name}}) do
    case Astarte.Housekeeping.Mock.DB.get_realm(realm_name) do
      nil ->
        generic_error(:realm_not_found)

      %Realm{
        realm_name: ^realm_name,
        jwt_public_key_pem: pem,
        replication_factor: rep,
        replication_class: class,
        datacenter_replication_factors: dc_repl,
        device_registration_limit: dev_reg_limit
      } ->
        %GetRealmReply{
          realm_name: realm_name,
          jwt_public_key_pem: pem,
          replication_factor: rep,
          replication_class: class,
          datacenter_replication_factors: dc_repl,
          device_registration_limit: dev_reg_limit
        }
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
    |> Reply.encode()
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
