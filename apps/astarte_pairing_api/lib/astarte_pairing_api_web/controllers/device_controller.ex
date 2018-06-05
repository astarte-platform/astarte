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

defmodule Astarte.Pairing.APIWeb.DeviceController do
  use Astarte.Pairing.APIWeb, :controller

  alias Astarte.Pairing.API.Credentials
  alias Astarte.Pairing.API.Credentials.AstarteMQTTV1
  alias Astarte.Pairing.API.Info
  alias Astarte.Pairing.API.Info.DeviceInfo
  alias Astarte.Pairing.APIWeb.CredentialsView
  alias Astarte.Pairing.APIWeb.CredentialsStatusView
  alias Astarte.Pairing.APIWeb.DeviceInfoView

  @bearer_regex ~r/bearer\:?\s+(.*)$/i

  action_fallback Astarte.Pairing.APIWeb.FallbackController

  def create_credentials(conn, %{
        "realm_name" => realm,
        "hw_id" => hw_id,
        "protocol" => "astarte_mqtt_v1",
        "data" => params
      }) do
    alias AstarteMQTTV1.Credentials, as: AstarteCredentials

    with device_ip <- get_ip(conn),
         {:ok, secret} <- get_secret(conn),
         {:ok, %AstarteCredentials{} = credentials} <-
           Credentials.get_astarte_mqtt_v1(realm, hw_id, secret, device_ip, params) do
      conn
      |> put_status(:created)
      |> render(CredentialsView, "show_astarte_mqtt_v1.json", credentials: credentials)
    end
  end

  def show_info(conn, %{"realm_name" => realm, "hw_id" => hw_id}) do
    with {:ok, secret} <- get_secret(conn),
         {:ok, %DeviceInfo{} = device_info} <- Info.get_device_info(realm, hw_id, secret) do
      render(conn, DeviceInfoView, "show.json", device_info: device_info)
    end
  end

  def verify_credentials(conn, %{
        "realm_name" => realm,
        "hw_id" => hw_id,
        "protocol" => "astarte_mqtt_v1",
        "data" => params
      }) do
    alias AstarteMQTTV1.CredentialsStatus, as: CredentialsStatus

    with {:ok, secret} <- get_secret(conn),
         {:ok, %CredentialsStatus{} = status} <-
           Credentials.verify_astarte_mqtt_v1(realm, hw_id, secret, params) do
      render(conn, CredentialsStatusView, "show_astarte_mqtt_v1.json", credentials_status: status)
    end
  end

  defp get_secret(conn) do
    auth_headers = get_req_header(conn, "authorization")
    find_secret(auth_headers)
  end

  defp find_secret([]) do
    {:error, :unauthorized}
  end

  defp find_secret([auth_header | tail]) do
    case Regex.run(@bearer_regex, auth_header) do
      [_, match] ->
        {:ok, match}

      _ ->
        find_secret(tail)
    end
  end

  defp get_ip(conn) do
    conn.remote_ip
    |> :inet_parse.ntoa()
    |> to_string()
  end
end
