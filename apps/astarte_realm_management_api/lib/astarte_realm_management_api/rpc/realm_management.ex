#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
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

defmodule Astarte.RealmManagement.API.RPC.RealmManagement do
  alias Astarte.RPC.Protocol.RealmManagement.{
    Call,
    DeleteInterface,
    DeleteTrigger,
    GenericErrorReply,
    GenericOkReply,
    GetDeviceRegistrationLimit,
    GetDeviceRegistrationLimitReply,
    GetHealth,
    GetHealthReply,
    GetInterfacesList,
    GetInterfacesListReply,
    GetInterfaceSource,
    GetInterfaceSourceReply,
    GetInterfaceVersionsList,
    GetInterfaceVersionsListReply,
    GetInterfaceVersionsListReplyVersionTuple,
    GetJWTPublicKeyPEM,
    GetJWTPublicKeyPEMReply,
    GetTrigger,
    GetTriggerReply,
    GetTriggersList,
    GetTriggersListReply,
    InstallInterface,
    InstallTrigger,
    Reply,
    UpdateInterface,
    UpdateJWTPublicKeyPEM,
    InstallTriggerPolicy,
    GetTriggerPoliciesList,
    GetTriggerPoliciesListReply,
    GetTriggerPolicySource,
    GetTriggerPolicySourceReply,
    DeleteTriggerPolicy,
    DeleteDevice
  }

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.Trigger
  alias Astarte.RealmManagement.API.Config

  require Logger

  @rpc_client Config.rpc_client!()
  @destination Astarte.RPC.Protocol.RealmManagement.amqp_queue()

  def get_interface_versions_list(realm_name, interface_name) do
    %GetInterfaceVersionsList{
      realm_name: realm_name,
      interface_name: interface_name
    }
    |> encode_call(:get_interface_versions_list)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_interfaces_list(realm_name) do
    %GetInterfacesList{
      realm_name: realm_name
    }
    |> encode_call(:get_interfaces_list)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_interface(realm_name, interface_name, interface_major_version) do
    %GetInterfaceSource{
      realm_name: realm_name,
      interface_name: interface_name,
      interface_major_version: interface_major_version
    }
    |> encode_call(:get_interface_source)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def install_interface(realm_name, interface_json, opts) do
    %InstallInterface{
      realm_name: realm_name,
      interface_json: interface_json,
      async_operation: Keyword.get(opts, :async_operation, true)
    }
    |> encode_call(:install_interface)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def update_interface(realm_name, interface_json, opts) do
    %UpdateInterface{
      realm_name: realm_name,
      interface_json: interface_json,
      async_operation: Keyword.get(opts, :async_operation, true)
    }
    |> encode_call(:update_interface)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def delete_interface(realm_name, interface_name, interface_major_version, opts) do
    %DeleteInterface{
      realm_name: realm_name,
      interface_name: interface_name,
      interface_major_version: interface_major_version,
      async_operation: Keyword.get(opts, :async_operation, true)
    }
    |> encode_call(:delete_interface)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_jwt_public_key_pem(realm_name) do
    %GetJWTPublicKeyPEM{
      realm_name: realm_name
    }
    |> encode_call(:get_jwt_public_key_pem)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_device_registration_limit(realm_name) do
    %GetDeviceRegistrationLimit{
      realm_name: realm_name
    }
    |> encode_call(:get_device_registration_limit)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def update_jwt_public_key_pem(realm_name, jwt_public_key_pem) do
    %UpdateJWTPublicKeyPEM{
      realm_name: realm_name,
      jwt_public_key_pem: jwt_public_key_pem
    }
    |> encode_call(:update_jwt_public_key_pem)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def install_trigger(realm_name, trigger_name, policy_name, action, tagged_simple_triggers) do
    serialized_tagged_simple_triggers =
      Enum.map(tagged_simple_triggers, &TaggedSimpleTrigger.encode/1)

    %InstallTrigger{
      realm_name: realm_name,
      trigger_name: trigger_name,
      action: action,
      serialized_tagged_simple_triggers: serialized_tagged_simple_triggers,
      trigger_policy: policy_name
    }
    |> encode_call(:install_trigger)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_trigger(realm_name, trigger_name) do
    %GetTrigger{
      realm_name: realm_name,
      trigger_name: trigger_name
    }
    |> encode_call(:get_trigger)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_triggers_list(realm_name) do
    %GetTriggersList{
      realm_name: realm_name
    }
    |> encode_call(:get_triggers_list)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def delete_trigger(realm_name, trigger_name) do
    %DeleteTrigger{
      realm_name: realm_name,
      trigger_name: trigger_name
    }
    |> encode_call(:delete_trigger)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_health do
    %GetHealth{}
    |> encode_call(:get_health)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_trigger_policies_list(realm_name) do
    %GetTriggerPoliciesList{
      realm_name: realm_name
    }
    |> encode_call(:get_trigger_policies_list)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_trigger_policy_source(realm_name, trigger_policy_name) do
    %GetTriggerPolicySource{
      realm_name: realm_name,
      trigger_policy_name: trigger_policy_name
    }
    |> encode_call(:get_trigger_policy_source)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def install_trigger_policy(realm_name, trigger_policy_json) do
    %InstallTriggerPolicy{
      realm_name: realm_name,
      trigger_policy_json: trigger_policy_json,
      async_operation: true
    }
    |> encode_call(:install_trigger_policy)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def delete_trigger_policy(realm_name, trigger_policy_name) do
    %DeleteTriggerPolicy{
      realm_name: realm_name,
      trigger_policy_name: trigger_policy_name,
      async_operation: true
    }
    |> encode_call(:delete_trigger_policy)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def delete_device(realm_name, device_id) do
    %DeleteDevice{
      realm_name: realm_name,
      device_id: device_id
    }
    |> encode_call(:delete_device)
    |> @rpc_client.rpc_call(@destination)
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

  defp decode_reply({:error, reason}) do
    {:error, reason}
  end

  defp extract_reply({:generic_ok_reply, %GenericOkReply{async_operation: async}}) do
    if async do
      {:ok, :started}
    else
      :ok
    end
  end

  defp extract_reply({:get_health_reply, %GetHealthReply{status: status}}) do
    lowercase_status =
      case status do
        :READY -> :ready
        :DEGRADED -> :degraded
        :BAD -> :bad
        :ERROR -> :error
      end

    {:ok, %{status: lowercase_status}}
  end

  defp extract_reply({:generic_error_reply, %GenericErrorReply{error_name: name}}) do
    try do
      reason = String.to_existing_atom(name)
      {:error, reason}
    rescue
      ArgumentError ->
        _ = Logger.warn("Received unknown error: #{inspect(name)}.", tag: "amqp_generic_error")
        {:error, :unknown}
    end
  end

  defp extract_reply(
         {:get_interface_versions_list_reply, %GetInterfaceVersionsListReply{versions: versions}}
       ) do
    result =
      for version <- versions do
        %GetInterfaceVersionsListReplyVersionTuple{
          major_version: major_version,
          minor_version: minor_version
        } = version

        [major_version: major_version, minor_version: minor_version]
      end

    {:ok, result}
  end

  defp extract_reply(
         {:get_interfaces_list_reply, %GetInterfacesListReply{interfaces_names: list}}
       ) do
    {:ok, list}
  end

  defp extract_reply({:get_interface_source_reply, %GetInterfaceSourceReply{source: source}}) do
    {:ok, source}
  end

  defp extract_reply(
         {:get_jwt_public_key_pem_reply, %GetJWTPublicKeyPEMReply{jwt_public_key_pem: pem}}
       ) do
    {:ok, pem}
  end

  defp extract_reply(
         {:get_trigger_reply,
          %GetTriggerReply{
            trigger_data: trigger_data,
            serialized_tagged_simple_triggers: serialized_tagged_simple_triggers
          }}
       ) do
    %Trigger{
      name: trigger_name,
      action: trigger_action,
      policy: policy
    } = Trigger.decode(trigger_data)

    tagged_simple_triggers =
      for serialized_tagged_simple_trigger <- serialized_tagged_simple_triggers do
        TaggedSimpleTrigger.decode(serialized_tagged_simple_trigger)
      end

    {:ok,
     %{
       trigger_name: trigger_name,
       trigger_action: trigger_action,
       tagged_simple_triggers: tagged_simple_triggers,
       policy: policy
     }}
  end

  defp extract_reply({:get_triggers_list_reply, %GetTriggersListReply{triggers_names: triggers}}) do
    {:ok, triggers}
  end

  defp extract_reply(
         {:get_trigger_policies_list_reply,
          %GetTriggerPoliciesListReply{trigger_policies_names: list}}
       ) do
    {:ok, list}
  end

  defp extract_reply(
         {:get_trigger_policy_source_reply, %GetTriggerPolicySourceReply{source: source}}
       ) do
    {:ok, source}
  end

  defp extract_reply(
         {:get_device_registration_limit_reply,
          %GetDeviceRegistrationLimitReply{device_registration_limit: limit}}
       ) do
    {:ok, limit}
  end

  defp extract_reply({:error, :rpc_error}) do
    {:error, :rpc_error}
  end
end
