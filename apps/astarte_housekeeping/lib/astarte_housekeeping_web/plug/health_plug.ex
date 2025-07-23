#
# This file is part of Astarte.
#
# Copyright 2020 - 2025 SECO Mind Srl
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

defmodule Astarte.HousekeepingWeb.HealthPlug do
  @moduledoc false
  @behaviour Plug

  import Plug.Conn

  alias Astarte.DataAccess.Health.Health

  def init(_opts) do
    nil
  end

  def call(%{request_path: "/health", method: "GET"} = conn, _opts) do
    try do
      case Health.get_health() do
        status when status in [:ready, :degraded] ->
          :telemetry.execute(
            [:astarte, :housekeeping, :service],
            %{health: 1},
            %{status: status}
          )

          conn
          |> send_resp(:ok, "")
          |> halt()

        _ ->
          :telemetry.execute(
            [:astarte, :housekeeping, :service],
            %{health: 0}
          )

          conn
          |> send_resp(:service_unavailable, "")
          |> halt()
      end
    rescue
      _ ->
        :telemetry.execute(
          [:astarte, :housekeeping, :service],
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
