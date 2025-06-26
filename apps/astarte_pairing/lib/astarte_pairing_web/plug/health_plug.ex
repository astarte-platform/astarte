#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule Astarte.PairingWeb.HealthPlug do
  @behaviour Plug
  import Plug.Conn

  alias Astarte.Pairing.Health
  alias Astarte.Pairing.Health.BackendHealth

  def init(_opts) do
    nil
  end

  def call(%{request_path: "/health", method: "GET"} = conn, _opts) do
    try do
      with {:ok, %BackendHealth{status: status}} <- Health.get_backend_health() do
        case status do
          # When degraded, some Cassandra nodes are available so it's still ok
          val when val in [:ready, :degraded] ->
            conn
            |> send_resp(:ok, "")
            |> halt()

          val when val in [:bad, :error] ->
            conn
            |> send_resp(:service_unavailable, "")
            |> halt()
        end
      end
    rescue
      _ ->
        :telemetry.execute(
          [:astarte, :pairing, :service],
          %{health: 0}
        )

        conn
        |> send_resp(:internal_server_error, "")
        |> halt()
    end
  end

  def call(conn, _opts) do
    conn
  end
end
