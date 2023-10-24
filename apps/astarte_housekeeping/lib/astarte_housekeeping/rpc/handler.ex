#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.Housekeeping.RPC.Handler do
  @behaviour Astarte.RPC.Handler

  alias Astarte.Housekeeping.Engine

  alias Astarte.RPC.Protocol.Housekeeping.{
    Call,
    CreateRealm,
    DeleteRealm,
    DoesRealmExist,
    DoesRealmExistReply,
    GenericErrorReply,
    GenericOkReply,
    GetHealth,
    GetHealthReply,
    GetRealm,
    GetRealmReply,
    GetRealmsList,
    GetRealmsListReply,
    Reply,
    UpdateRealm
  }

  require Logger

  def handle_rpc(payload) do
    with {:ok, call_tuple} <- extract_call_tuple(Call.decode(payload)) do
      call_rpc(call_tuple)
    end
  end

  defp extract_call_tuple(%Call{call: nil}) do
    _ = Logger.warn("Received empty call.", tag: "rpc_call_empty")
    {:error, :empty_call}
  end

  defp extract_call_tuple(%Call{call: call_tuple}) do
    {:ok, call_tuple}
  end

  # Here for retrocompatibility with old protos serialized with Exprotobuf
  defp call_rpc({:create_realm, %CreateRealm{realm: ""}}) do
    _ = Logger.warn("CreateRealm with empty realm.", tag: "rpc_create_nil_realm")
    generic_error(:empty_name, "empty realm name")
  end

  # Here for retrocompatibility with old protos serialized with Exprotobuf
  defp call_rpc({:create_realm, %CreateRealm{jwt_public_key_pem: ""}}) do
    _ =
      Logger.warn("CreateRealm with empty jwt_public_key_pem.", tag: "rpc_create_nil_public_key")

    generic_error(:empty_public_key, "empty jwt public key pem")
  end

  defp call_rpc({:create_realm, %CreateRealm{realm: nil}}) do
    _ = Logger.warn("CreateRealm with empty realm.", tag: "rpc_create_nil_realm")
    generic_error(:empty_name, "empty realm name")
  end

  defp call_rpc({:create_realm, %CreateRealm{jwt_public_key_pem: nil}}) do
    _ =
      Logger.warn("CreateRealm with empty jwt_public_key_pem.", tag: "rpc_create_nil_public_key")

    generic_error(:empty_public_key, "empty jwt public key pem")
  end

  defp call_rpc(
         {:create_realm,
          %CreateRealm{
            realm: realm,
            jwt_public_key_pem: pub_key,
            replication_class: :NETWORK_TOPOLOGY_STRATEGY,
            datacenter_replication_factors: datacenter_replication_factors,
            device_registration_limit: device_registration_limit,
            async_operation: async
          }}
       ) do
    with {:ok, false} <- Astarte.Housekeeping.Engine.is_realm_existing(realm),
         datacenter_replication_factors_map = Enum.into(datacenter_replication_factors, %{}),
         :ok <-
           Engine.create_realm(
             realm,
             pub_key,
             datacenter_replication_factors_map,
             device_registration_limit,
             async: async
           ) do
      generic_ok(async)
    else
      # This comes from is_realm_existing
      {:ok, true} ->
        _ =
          Logger.warn("CreateRealm with already existing realm.",
            tag: "rpc_create_existing_realm",
            realm: realm
          )

        generic_error(:existing_realm, "realm already exists")

      {:error, {reason, details}} ->
        generic_error(reason, details)

      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp call_rpc({:create_realm, %CreateRealm{replication_factor: 0} = call}) do
    # Due to new proto3 defaults, if replication factor is not explictly set, it now defaults
    # to 0 instead of nil. Hide this implementation detail to the outside world.
    call_rpc({:create_realm, %{call | replication_factor: nil}})
  end

  defp call_rpc(
         {:create_realm,
          %CreateRealm{
            realm: realm,
            jwt_public_key_pem: pub_key,
            replication_factor: replication_factor,
            device_registration_limit: device_registration_limit,
            async_operation: async
          }}
       ) do
    with {:ok, false} <- Astarte.Housekeeping.Engine.is_realm_existing(realm),
         :ok <-
           Engine.create_realm(realm, pub_key, replication_factor, device_registration_limit,
             async: async
           ) do
      generic_ok(async)
    else
      # This comes from is_realm_existing
      {:ok, true} ->
        _ =
          Logger.warn("CreateRealm with already existing realm.",
            tag: "rpc_create_existing_realm",
            realm: realm
          )

        generic_error(:existing_realm, "realm already exists")

      {:error, {reason, details}} ->
        generic_error(reason, details)

      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp call_rpc({:update_realm, %UpdateRealm{} = call}) do
    with {:ok, realm} <- Astarte.Housekeeping.Engine.update_realm(call.realm, call) do
      case realm do
        %{
          realm_name: realm_name_reply,
          jwt_public_key_pem: public_key,
          replication_class: "SimpleStrategy",
          replication_factor: replication_factor
        } ->
          %GetRealmReply{
            realm_name: realm_name_reply,
            jwt_public_key_pem: public_key,
            replication_class: :SIMPLE_STRATEGY,
            replication_factor: replication_factor
          }
          |> encode_reply(:get_realm_reply)
          |> ok_wrap

        %{
          realm_name: realm_name_reply,
          jwt_public_key_pem: public_key,
          replication_class: "NetworkTopologyStrategy",
          datacenter_replication_factors: datacenter_replication_factors
        } ->
          %GetRealmReply{
            realm_name: realm_name_reply,
            jwt_public_key_pem: public_key,
            replication_class: :NETWORK_TOPOLOGY_STRATEGY,
            datacenter_replication_factors: datacenter_replication_factors
          }
          |> encode_reply(:get_realm_reply)
          |> ok_wrap
      end
    else
      {:error, reason} ->
        generic_error(reason)
    end
  end

  # Here for retrocompatibility with old protos serialized with Exprotobuf
  defp call_rpc({:delete_realm, %DeleteRealm{realm: ""}}) do
    _ = Logger.warn("DeleteRealm with empty realm.", tag: "rpc_delete_empty_realm")
    generic_error(:empty_name, "empty realm name")
  end

  defp call_rpc({:delete_realm, %DeleteRealm{realm: nil}}) do
    _ = Logger.warn("DeleteRealm with empty realm.", tag: "rpc_delete_empty_realm")
    generic_error(:empty_name, "empty realm name")
  end

  defp call_rpc({:delete_realm, %DeleteRealm{realm: realm, async_operation: async}}) do
    with {:ok, true} <- Engine.is_realm_existing(realm),
         :ok <- Engine.delete_realm(realm, async: async) do
      generic_ok(async)
    else
      {:ok, false} ->
        _ =
          Logger.warn("DeleteRealm with non-existing realm.",
            tag: "rpc_delete_non_existing_realm",
            realm: realm
          )

        generic_error(:realm_not_found)

      {:error, {reason, details}} ->
        generic_error(reason, details)

      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp call_rpc({:does_realm_exist, %DoesRealmExist{realm: realm}}) do
    case Astarte.Housekeeping.Engine.is_realm_existing(realm) do
      {:ok, exists?} ->
        %DoesRealmExistReply{exists: exists?}
        |> encode_reply(:does_realm_exist_reply)
        |> ok_wrap

      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp call_rpc({:get_health, %GetHealth{}}) do
    {:ok, %{status: status}} = Engine.get_health()

    status_enum =
      case status do
        :ready -> :READY
        :degraded -> :DEGRADED
        :bad -> :BAD
        :error -> :ERROR
      end

    %GetHealthReply{status: status_enum}
    |> encode_reply(:get_health_reply)
    |> ok_wrap
  end

  defp call_rpc({:get_realms_list, %GetRealmsList{}}) do
    case Astarte.Housekeeping.Engine.list_realms() do
      {:ok, list} ->
        %GetRealmsListReply{realms_names: list}
        |> encode_reply(:get_realms_list_reply)
        |> ok_wrap

      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp call_rpc({:get_realm, %GetRealm{realm_name: realm_name}}) do
    case Astarte.Housekeeping.Engine.get_realm(realm_name) do
      %{
        realm_name: realm_name_reply,
        jwt_public_key_pem: public_key,
        replication_class: "SimpleStrategy",
        replication_factor: replication_factor
      } ->
        %GetRealmReply{
          realm_name: realm_name_reply,
          jwt_public_key_pem: public_key,
          replication_class: :SIMPLE_STRATEGY,
          replication_factor: replication_factor
        }
        |> encode_reply(:get_realm_reply)
        |> ok_wrap

      %{
        realm_name: realm_name_reply,
        jwt_public_key_pem: public_key,
        replication_class: "NetworkTopologyStrategy",
        datacenter_replication_factors: datacenter_replication_factors
      } ->
        datacenter_replication_factors_list = Enum.into(datacenter_replication_factors, [])

        %GetRealmReply{
          realm_name: realm_name_reply,
          jwt_public_key_pem: public_key,
          replication_class: :NETWORK_TOPOLOGY_STRATEGY,
          datacenter_replication_factors: datacenter_replication_factors_list
        }
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
    %Reply{reply: {reply_type, reply}, error: false}
    |> Reply.encode()
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
