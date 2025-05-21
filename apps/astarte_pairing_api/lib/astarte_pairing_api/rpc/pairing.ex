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

defmodule Astarte.Pairing.API.RPC.Pairing do
  @moduledoc """
  This module sends RPC to the astarte_pairing backend
  """

  alias Astarte.Pairing.API.Config

  @rpc_client Config.rpc_client!()
  @destination Astarte.RPC.Protocol.Pairing.amqp_queue()

  alias Astarte.RPC.Protocol.Pairing.{
    AstarteMQTTV1CredentialsParameters,
    AstarteMQTTV1Credentials,
    AstarteMQTTV1CredentialsStatus,
    Call,
    GenericErrorReply,
    GenericOkReply,
    GetAgentPublicKeyPEMs,
    GetAgentPublicKeyPEMsReply,
    GetCredentials,
    GetCredentialsReply,
    GetHealth,
    GetHealthReply,
    GetInfo,
    GetInfoReply,
    IntrospectionEntry,
    ProtocolStatus,
    RegisterDevice,
    RegisterDeviceReply,
    Reply,
    UnregisterDevice,
    VerifyCredentials,
    VerifyCredentialsReply
  }

  require Logger

  @timeout 30_000

  def get_agent_public_key_pems(realm) do
    %GetAgentPublicKeyPEMs{realm: realm}
    |> encode_call(:get_agent_public_key_pems)
    |> @rpc_client.rpc_call(@destination, @timeout)
    |> decode_reply()
    |> extract_reply()
  end

  def get_info(realm, hw_id, secret) do
    %GetInfo{realm: realm, hw_id: hw_id, secret: secret}
    |> encode_call(:get_info)
    |> @rpc_client.rpc_call(@destination, @timeout)
    |> decode_reply()
    |> extract_reply()
  end

  def get_health do
    %GetHealth{}
    |> encode_call(:get_health)
    |> @rpc_client.rpc_call(@destination, @timeout)
    |> decode_reply()
    |> extract_reply()
  end

  def register_device(realm, hw_id, initial_introspection \\ %{}) do
    initial_introspection_entries =
      Enum.map(initial_introspection, fn {interface_name, %{"major" => major, "minor" => minor}} ->
        %IntrospectionEntry{
          interface_name: interface_name,
          major_version: major,
          minor_version: minor
        }
      end)

    %RegisterDevice{
      realm: realm,
      hw_id: hw_id,
      initial_introspection: initial_introspection_entries
    }
    |> encode_call(:register_device)
    |> @rpc_client.rpc_call(@destination, @timeout)
    |> decode_reply()
    |> extract_reply()
  end

  def unregister_device(realm, device_id) do
    %UnregisterDevice{realm: realm, device_id: device_id}
    |> encode_call(:unregister_device)
    |> @rpc_client.rpc_call(@destination, @timeout)
    |> decode_reply()
    |> extract_reply()
  end

  def get_astarte_mqtt_v1_credentials(realm, hw_id, secret, device_ip, %{csr: csr}) do
    credentials_parameters = {:astarte_mqtt_v1, %AstarteMQTTV1CredentialsParameters{csr: csr}}

    %GetCredentials{
      realm: realm,
      hw_id: hw_id,
      secret: secret,
      device_ip: device_ip,
      credentials_parameters: credentials_parameters
    }
    |> encode_call(:get_credentials)
    |> @rpc_client.rpc_call(@destination, @timeout)
    |> decode_reply()
    |> extract_reply()
  end

  def verify_astarte_mqtt_v1_credentials(realm, hw_id, secret, %{client_crt: client_crt}) do
    credentials = {:astarte_mqtt_v1, %AstarteMQTTV1Credentials{client_crt: client_crt}}

    %VerifyCredentials{realm: realm, hw_id: hw_id, secret: secret, credentials: credentials}
    |> encode_call(:verify_credentials)
    |> @rpc_client.rpc_call(@destination, @timeout)
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
    _ = Logger.warning("rpc_call failed with error #{inspect(reason)}.", tag: "rpc_call_error")
    {:error, :rpc_error}
  end

  defp extract_reply(
         {:get_agent_public_key_pems_reply,
          %GetAgentPublicKeyPEMsReply{agent_public_key_pems: pems}}
       ) do
    {:ok, pems}
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

  defp extract_reply(
         {:get_info_reply,
          %GetInfoReply{version: version, device_status: device_status, protocols: protocols}}
       ) do
    protocols_map =
      Enum.reduce(protocols, %{}, fn %ProtocolStatus{} = element, acc ->
        %ProtocolStatus{
          status: {protocol_name, protocol_status_struct}
        } = element

        protocol_status_map = Map.from_struct(protocol_status_struct)
        Map.put(acc, protocol_name, protocol_status_map)
      end)

    {:ok, %{status: device_status, version: version, protocols: protocols_map}}
  end

  defp extract_reply({:register_device_reply, %RegisterDeviceReply{credentials_secret: secret}}) do
    {:ok, %{credentials_secret: secret}}
  end

  defp extract_reply({:get_credentials_reply, %GetCredentialsReply{credentials: credentials}}) do
    extract_credentials(credentials)
  end

  defp extract_reply(
         {:verify_credentials_reply,
          %VerifyCredentialsReply{credentials_status: credentials_status}}
       ) do
    extract_credentials_status(credentials_status)
  end

  defp extract_reply({:generic_error_reply, %GenericErrorReply{error_name: "forbidden"}}) do
    {:error, :forbidden}
  end

  defp extract_reply({:generic_error_reply, %GenericErrorReply{error_name: "realm_not_found"}}) do
    {:error, :forbidden}
  end

  defp extract_reply({:generic_error_reply, %GenericErrorReply{error_name: "device_not_found"}}) do
    {:error, :forbidden}
  end

  defp extract_reply(
         {:generic_error_reply, %GenericErrorReply{error_name: "device_not_registered"}}
       ) do
    {:error, :device_not_found}
  end

  defp extract_reply({:generic_error_reply, error_struct = %GenericErrorReply{}}) do
    error_map = Map.from_struct(error_struct)

    {:error, error_map}
  end

  defp extract_reply({:generic_ok_reply, %GenericOkReply{}}) do
    :ok
  end

  defp extract_reply({:error, :rpc_error}) do
    {:error, :rpc_error}
  end

  defp extract_credentials({:astarte_mqtt_v1, %AstarteMQTTV1Credentials{client_crt: client_crt}}) do
    {:ok, client_crt}
  end

  defp extract_credentials_status({:astarte_mqtt_v1, %AstarteMQTTV1CredentialsStatus{} = status}) do
    %AstarteMQTTV1CredentialsStatus{
      valid: valid,
      timestamp: timestamp,
      until: until,
      cause: cause,
      details: details
    } = status

    reply = %{
      valid: valid,
      timestamp: timestamp,
      until: until,
      cause: cause,
      details: details
    }

    {:ok, reply}
  end
end
