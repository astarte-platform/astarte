#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.API.Helpers.RPCMock do
  alias Astarte.RPC.Protocol.RealmManagement.{
    Call,
    GetDatastreamMaximumStorageRetention,
    GetDatastreamMaximumStorageRetentionReply,
    GenericOkReply,
    GetInterfacesList,
    GetInterfacesListReply,
    GetInterfaceVersionsList,
    GetInterfaceVersionsListReply,
    GetInterfaceVersionsListReplyVersionTuple,
    GetJWTPublicKeyPEM,
    GetJWTPublicKeyPEMReply,
    Reply,
    UpdateJWTPublicKeyPEM,
    GetDeviceRegistrationLimit,
    GetDeviceRegistrationLimitReply
  }

  alias Astarte.RealmManagement.API.Helpers.RPCMock.DB

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

  defp execute_rpc({:get_interfaces_list, %GetInterfacesList{realm_name: realm_name}}) do
    list = DB.get_interfaces_list(realm_name)

    %GetInterfacesListReply{interfaces_names: list}
    |> encode_reply(:get_interfaces_list_reply)
    |> ok_wrap
  end

  defp execute_rpc(
         {:get_interface_versions_list,
          %GetInterfaceVersionsList{realm_name: realm_name, interface_name: name}}
       ) do
    list = DB.get_interface_versions_list(realm_name, name)

    versions =
      for el <- list do
        %GetInterfaceVersionsListReplyVersionTuple{
          major_version: el[:major_version],
          minor_version: el[:minor_version]
        }
      end

    %GetInterfaceVersionsListReply{versions: versions}
    |> encode_reply(:get_interface_versions_list_reply)
    |> ok_wrap
  end

  defp execute_rpc({:get_jwt_public_key_pem, %GetJWTPublicKeyPEM{realm_name: realm_name}}) do
    pem = DB.get_jwt_public_key_pem(realm_name)

    %GetJWTPublicKeyPEMReply{jwt_public_key_pem: pem}
    |> encode_reply(:get_jwt_public_key_pem_reply)
    |> ok_wrap
  end

  defp execute_rpc(
         {:update_jwt_public_key_pem,
          %UpdateJWTPublicKeyPEM{realm_name: realm_name, jwt_public_key_pem: pem}}
       ) do
    :ok = DB.put_jwt_public_key_pem(realm_name, pem)

    generic_ok()
    |> ok_wrap
  end

  defp execute_rpc(
         {:get_device_registration_limit,
          %GetDeviceRegistrationLimit{
            realm_name: realm_name
          }}
       ) do
    value = DB.get_device_registration_limit(realm_name)

    %GetDeviceRegistrationLimitReply{device_registration_limit: value}
    |> encode_reply(:get_device_registration_limit_reply)
    |> ok_wrap
  end

  defp execute_rpc(
         {:get_datastream_maximum_storage_retention,
          %GetDatastreamMaximumStorageRetention{
            realm_name: realm_name
          }}
       ) do
    value = DB.get_datastream_maximum_storage_retention(realm_name)

    %GetDatastreamMaximumStorageRetentionReply{datastream_maximum_storage_retention: value}
    |> encode_reply(:get_datastream_maximum_storage_retention_reply)
    |> ok_wrap
  end

  defp generic_ok(async_operation \\ false) do
    %GenericOkReply{async_operation: async_operation}
    |> encode_reply(:generic_ok_reply)
  end

  defp encode_reply(reply, reply_type, opts \\ []) do
    error = Keyword.get(opts, :error, false)

    %Reply{reply: {reply_type, reply}, error: error}
    |> Reply.encode()
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
