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

defmodule Astarte.Pairing.APIWeb.Plug.FixLegacyPairingMIME do
  import Plug.Conn

  def init(_opts), do: false

  def call(conn, _opts) do
    if legacy_pairing?(conn.request_path) do
      conn
      |> put_req_header("content-type", "application/astarte-legacy-pairing")
    else
      conn
    end
  end

  defp legacy_pairing?("/api/v1/pairing"), do: true

  defp legacy_pairing?("/api/v1/verifyCertificate"), do: true

  defp legacy_pairing?(_), do: false
end
