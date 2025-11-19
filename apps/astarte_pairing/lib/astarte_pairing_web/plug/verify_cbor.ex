# FIXME: this will generate a conflict, please ignore this version and keep what's been already merged
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.PairingWeb.Plug.VerifyCbor do
  use Plug.Builder

  import Plug.Conn

  def init(_opts) do
    nil
  end

  def call(conn, _opts) do
    if get_req_header(conn, "content-type") == ["application/cbor"] do
      case Plug.Conn.read_body(conn) do
        {:ok, body, conn} ->
          conn |> Plug.Conn.assign(:cbor_body, body)

        _ ->
          conn |> Plug.Conn.send_resp(400, "Could not read request body.") |> halt()
      end
    else
      conn
      |> Plug.Conn.send_resp(415, "Unsupported Media Type. Expected application/cbor.")
      |> halt()
    end
  end
end
