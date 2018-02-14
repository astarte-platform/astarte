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
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.Pairing.APIWeb.CertificateController do
  use Astarte.Pairing.APIWeb, :controller

  alias Astarte.Pairing.API.Pairing
  alias Astarte.Pairing.API.Pairing.Certificate
  alias Astarte.Pairing.API.Pairing.CertificateStatus
  alias Astarte.Pairing.APIWeb.CertificateStatusView

  action_fallback Astarte.Pairing.APIWeb.FallbackController

  def create(conn, %{"data" => csr}) do
    with device_ip <- get_ip(conn),
         {:ok, api_key} <- get_api_key(conn),
         params = %{"csr" => csr, "api_key" => api_key, "device_ip" => device_ip},
         {:ok, %Certificate{} = certificate} <- Pairing.pair(params) do
      conn
      |> put_status(:created)
      |> render("show.json", certificate: certificate)
    end
  end

  def verify(conn, %{"data" => certificate}) do
    with {:ok, %CertificateStatus{} = status} <- Pairing.verify_certificate(%{"certificate" => certificate}) do
      conn
      |> put_status(:created)
      |> render(CertificateStatusView, "show.json", certificate_status: status)
    end
  end

  defp get_api_key(conn) do
    case get_req_header(conn, "x-api-key") do
      [api_key] -> {:ok, api_key}
      [] -> {:error, :unauthorized}
    end
  end

  defp get_ip(conn) do
    conn.remote_ip
    |> :inet_parse.ntoa()
    |> to_string()
  end
end
