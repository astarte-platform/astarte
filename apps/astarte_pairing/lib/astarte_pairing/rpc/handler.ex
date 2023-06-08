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

defmodule Astarte.Pairing.RPC.Handler do
  @moduledoc false

  @behaviour Astarte.RPC.Handler

  alias Astarte.Pairing.Engine

  alias Astarte.RPC.Protocol.Pairing.{
    AstarteMQTTV1Credentials,
    AstarteMQTTV1CredentialsParameters,
    AstarteMQTTV1CredentialsStatus,
    AstarteMQTTV1Status,
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

  defp call_rpc({:get_agent_public_key_pems, %GetAgentPublicKeyPEMs{realm: realm}})
       when is_binary(realm) do
    with {:ok, pems} <- Engine.get_agent_public_key_pems(realm) do
      %GetAgentPublicKeyPEMsReply{agent_public_key_pems: pems}
      |> encode_reply(:get_agent_public_key_pems_reply)
      |> ok_wrap()
    else
      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp call_rpc(
         {:get_credentials,
          %GetCredentials{
            realm: realm,
            hw_id: hw_id,
            secret: secret,
            device_ip: device_ip,
            credentials_parameters: credentials_parameters
          }}
       ) do
    with {:ok, {protocol, parameters}} <- extract_credentials_request(credentials_parameters),
         {:ok, credentials_map} <-
           Engine.get_credentials(protocol, parameters, realm, hw_id, secret, device_ip),
         {:ok, credentials} <- build_credentials(protocol, credentials_map) do
      %GetCredentialsReply{credentials: credentials}
      |> encode_reply(:get_credentials_reply)
      |> ok_wrap()
    else
      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp call_rpc({:get_info, %GetInfo{realm: realm, hw_id: hw_id, secret: secret}}) do
    with {:ok, %{device_status: status, version: version, protocols: protocol_info}} <-
           Engine.get_info(realm, hw_id, secret) do
      protocol_list = build_protocol_list(protocol_info)

      %GetInfoReply{device_status: status, version: version, protocols: protocol_list}
      |> encode_reply(:get_info_reply)
      |> ok_wrap()
    else
      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp call_rpc(
         {:register_device,
          %RegisterDevice{
            realm: realm,
            hw_id: hw_id,
            initial_introspection: initial_introspection
          }}
       ) do
    initial_introspection_maps = Enum.map(initial_introspection, &Map.from_struct/1)

    case Engine.register_device(realm, hw_id, initial_introspection: initial_introspection_maps) do
      {:ok, credentials_secret} ->
        %RegisterDeviceReply{credentials_secret: credentials_secret}
        |> encode_reply(:register_device_reply)
        |> ok_wrap()

      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp call_rpc({:unregister_device, %UnregisterDevice{realm: realm, device_id: device_id}}) do
    case Engine.unregister_device(realm, device_id) do
      :ok ->
        generic_ok()

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
    |> ok_wrap()
  end

  defp call_rpc(
         {:verify_credentials,
          %VerifyCredentials{realm: realm, hw_id: hw_id, secret: secret, credentials: credentials}}
       ) do
    with {:ok, {protocol, credentials_map}} <- extract_credentials(credentials),
         {:ok, credentials_status_map} <-
           Engine.verify_credentials(protocol, credentials_map, realm, hw_id, secret),
         {:ok, credentials_status} <- build_credentials_status(protocol, credentials_status_map) do
      %VerifyCredentialsReply{credentials_status: credentials_status}
      |> encode_reply(:verify_credentials_reply)
      |> ok_wrap()
    else
      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp extract_credentials({:astarte_mqtt_v1, %AstarteMQTTV1Credentials{client_crt: client_crt}}) do
    {:ok, {:astarte_mqtt_v1, %{client_crt: client_crt}}}
  end

  defp extract_credentials(_credentials) do
    {:error, :unknown_protocol}
  end

  defp extract_credentials_request(
         {:astarte_mqtt_v1, %AstarteMQTTV1CredentialsParameters{csr: csr}}
       ) do
    {:ok, {:astarte_mqtt_v1, %{csr: csr}}}
  end

  defp extract_credentials_request(_credentials_request) do
    {:error, :unknown_protocol}
  end

  defp build_credentials(:astarte_mqtt_v1, credentials_map) do
    %{
      client_crt: client_crt
    } = credentials_map

    {:ok, {:astarte_mqtt_v1, %AstarteMQTTV1Credentials{client_crt: client_crt}}}
  end

  defp build_credentials(_protocol, _params) do
    {:error, :unknown_protocol}
  end

  defp build_credentials_status(:astarte_mqtt_v1, %{valid: true} = status_map) do
    %{
      timestamp: timestamp,
      until: until
    } = status_map

    status = %AstarteMQTTV1CredentialsStatus{
      valid: true,
      timestamp: timestamp,
      until: until
    }

    {:ok, {:astarte_mqtt_v1, status}}
  end

  defp build_credentials_status(:astarte_mqtt_v1, %{valid: false} = status_map) do
    %{
      timestamp: timestamp,
      reason: reason
    } = status_map

    status = %AstarteMQTTV1CredentialsStatus{
      valid: false,
      timestamp: timestamp,
      cause: reason_to_certificate_validation_error(reason)
    }

    {:ok, {:astarte_mqtt_v1, status}}
  end

  defp build_credentials_status(_protocol, _params) do
    {:error, :unknown_protocol}
  end

  defp build_protocol_list(protocol_info) do
    Enum.reduce(protocol_info, [], fn {protocol_id, protocol_map}, acc ->
      with {:ok, protocol_status} <- build_protocol_status(protocol_id, protocol_map) do
        [protocol_status | acc]
      else
        err ->
          # We skip it and keep going since if we crash we block all pairing
          Logger.warn(
            "Error while building protocol status: #{inspect(err)} with protocol_map #{inspect(protocol_map)}"
          )

          acc
      end
    end)
  end

  defp build_protocol_status(:astarte_mqtt_v1, %{broker_url: url}) do
    protocol_status = %ProtocolStatus{
      status: {:astarte_mqtt_v1, %AstarteMQTTV1Status{broker_url: url}}
    }

    {:ok, protocol_status}
  end

  defp build_protocol_status(_protocol_id, _protocol_map) do
    {:error, :unknown_protocol}
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
    |> ok_wrap()
  end

  defp generic_ok do
    %GenericOkReply{async_operation: false}
    |> encode_reply(:generic_ok_reply)
    |> ok_wrap()
  end

  defp reason_to_certificate_validation_error(:cert_expired), do: :EXPIRED
  defp reason_to_certificate_validation_error(:invalid_issuer), do: :INVALID_ISSUER
  defp reason_to_certificate_validation_error(:invalid_signature), do: :INVALID_SIGNATURE
  defp reason_to_certificate_validation_error(:name_not_permitted), do: :NAME_NOT_PERMITTED

  defp reason_to_certificate_validation_error(:missing_basic_constraint),
    do: :MISSING_BASIC_CONSTRAINT

  defp reason_to_certificate_validation_error(:invalid_key_usage), do: :INVALID_KEY_USAGE
  defp reason_to_certificate_validation_error(:revoked), do: :REVOKED
  defp reason_to_certificate_validation_error(_), do: :INVALID

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
