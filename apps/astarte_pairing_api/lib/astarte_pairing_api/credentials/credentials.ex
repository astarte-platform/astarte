#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind Srl
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

defmodule Astarte.Pairing.API.Credentials do
  @moduledoc """
  The Credentials context.
  """

  alias Astarte.Pairing.API.Credentials.AstarteMQTTV1
  alias Astarte.Pairing.API.Engine

  def get_astarte_mqtt_v1(realm, hw_id, secret, device_ip, params) do
    alias AstarteMQTTV1.CredentialsRequest, as: CredentialsRequest
    alias AstarteMQTTV1.Credentials, as: Credentials

    changeset =
      %CredentialsRequest{}
      |> CredentialsRequest.changeset(params)

    with {:ok, %CredentialsRequest{csr: csr}} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, %{client_crt: client_crt}} <-
           Engine.get_credentials(:astarte_mqtt_v1, %{csr: csr}, realm, hw_id, secret, device_ip) do
      {:ok, %Credentials{client_crt: client_crt}}
    end
  end

  def verify_astarte_mqtt_v1(realm, hw_id, secret, params) do
    alias AstarteMQTTV1.Credentials, as: Credentials

    changeset =
      %Credentials{}
      |> Credentials.changeset(params)

    with {:ok, %Credentials{client_crt: client_crt}} <-
           Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, credentials_status_map} <-
           Engine.verify_credentials(
             :astarte_mqtt_v1,
             %{client_crt: client_crt},
             realm,
             hw_id,
             secret
           ) do
      {:ok, build_astarte_mqtt_v1_credentials_status(credentials_status_map)}
    end
  end

  defp build_astarte_mqtt_v1_credentials_status(%{valid: true} = status_map) do
    %{
      timestamp: timestamp,
      until: until
    } = status_map

    %AstarteMQTTV1.CredentialsStatus{
      valid: true,
      timestamp: timestamp,
      until: until,
      cause: nil,
      details: nil
    }
  end

  defp build_astarte_mqtt_v1_credentials_status(%{valid: false} = status_map) do
    %{
      timestamp: timestamp,
      reason: reason
    } = status_map

    %AstarteMQTTV1.CredentialsStatus{
      valid: false,
      timestamp: timestamp,
      cause: reason_to_certificate_validation_error(reason),
      details: nil,
      until: nil
    }
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
end
