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

defmodule Astarte.Pairing.API.Credentials do
  @moduledoc """
  The Credentials context.
  """

  alias Astarte.Pairing.API.Credentials.AstarteMQTTV1
  alias Astarte.Pairing.API.RPC.Pairing
  alias Astarte.Pairing.API.Utils

  def get_astarte_mqtt_v1(realm, hw_id, secret, device_ip, params) do
    alias AstarteMQTTV1.CredentialsRequest, as: CredentialsRequest
    alias AstarteMQTTV1.Credentials, as: Credentials

    changeset =
      %CredentialsRequest{}
      |> CredentialsRequest.changeset(params)

    with {:ok, %CredentialsRequest{csr: csr}} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, certificate} <-
           Pairing.get_astarte_mqtt_v1_credentials(realm, hw_id, secret, device_ip, %{csr: csr}) do
      {:ok, %Credentials{client_crt: certificate}}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, %{} = error_map} ->
        {:error, Utils.error_map_into_changeset(changeset, error_map)}

      {:error, :forbidden} ->
        {:error, :forbidden}

      {:error, _other} ->
        {:error, :rpc_error}
    end
  end

  def verify_astarte_mqtt_v1(realm, hw_id, secret, params) do
    alias AstarteMQTTV1.Credentials, as: Credentials
    alias AstarteMQTTV1.CredentialsStatus, as: CredentialsStatus

    changeset =
      %Credentials{}
      |> Credentials.changeset(params)

    with {:ok, %Credentials{client_crt: client_crt}} <-
           Ecto.Changeset.apply_action(changeset, :insert),
         {:ok,
          %{valid: valid, timestamp: timestamp, cause: cause, until: until, details: details}} <-
           Pairing.verify_astarte_mqtt_v1_credentials(realm, hw_id, secret, %{
             client_crt: client_crt
           }) do
      credentials_status = %CredentialsStatus{
        valid: valid,
        timestamp: timestamp,
        cause: cause,
        until: until,
        details: details
      }

      {:ok, credentials_status}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, %{} = error_map} ->
        {:error, Utils.error_map_into_changeset(changeset, error_map)}

      {:error, :forbidden} ->
        {:error, :forbidden}

      {:error, _reason} ->
        {:error, :rpc_error}
    end
  end
end
