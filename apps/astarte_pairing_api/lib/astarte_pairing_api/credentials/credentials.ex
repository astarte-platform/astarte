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
