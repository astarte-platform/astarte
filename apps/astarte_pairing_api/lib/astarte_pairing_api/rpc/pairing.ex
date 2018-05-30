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

defmodule Astarte.Pairing.API.RPC.Pairing do
  @moduledoc """
  This module sends RPC to the astarte_pairing backend
  """

  alias Astarte.Pairing.API.Config

  @rpc_client Config.rpc_client()
  @destination Astarte.RPC.Protocol.Pairing.amqp_queue()

  alias Astarte.RPC.Protocol.Pairing.{
    AstarteMQTTV1CredentialsParameters,
    AstarteMQTTV1Credentials,
    AstarteMQTTV1CredentialsStatus,
    Call,
    GenericErrorReply,
    GetAgentPublicKeyPEMs,
    GetAgentPublicKeyPEMsReply,
    GetCredentials,
    GetCredentialsReply,
    GetInfo,
    GetInfoReply,
    ProtocolStatus,
    RegisterDevice,
    RegisterDeviceReply,
    Reply,
    VerifyCredentials,
    VerifyCredentialsReply
  }

  def get_agent_public_key_pems(realm) do
    %GetAgentPublicKeyPEMs{realm: realm}
    |> encode_call(:get_agent_public_key_pems)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def get_info(realm, hw_id, secret) do
    %GetInfo{realm: realm, hw_id: hw_id, secret: secret}
    |> encode_call(:get_info)
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def register_device(realm, hw_id) do
    %RegisterDevice{realm: realm, hw_id: hw_id}
    |> encode_call(:register_device)
    |> @rpc_client.rpc_call(@destination)
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
    |> @rpc_client.rpc_call(@destination)
    |> decode_reply()
    |> extract_reply()
  end

  def verify_astarte_mqtt_v1_credentials(realm, hw_id, secret, %{client_crt: client_crt}) do
    credentials = {:astarte_mqtt_v1, %AstarteMQTTV1Credentials{client_crt: client_crt}}

    %VerifyCredentials{realm: realm, hw_id: hw_id, secret: secret, credentials: credentials}
    |> encode_call(:verify_credentials)
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

  defp extract_reply(
         {:get_agent_public_key_pems_reply,
          %GetAgentPublicKeyPEMsReply{agent_public_key_pems: pems}}
       ) do
    {:ok, pems}
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

  defp extract_reply({:generic_error_reply, error_struct = %GenericErrorReply{}}) do
    error_map = Map.from_struct(error_struct)

    {:error, error_map}
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
