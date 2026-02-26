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

defmodule Astarte.AppEngine.APIWeb.HealthPlug do
  @moduledoc """
  Plug dedicated to handling heatlh check requests.
  It intercepts GET requests to the /health endpoint and reports the service status based on the availability.
  It also emits telemetry events for monitoring purposes.
  """
  @behaviour Plug
  import Plug.Conn

  alias Astarte.AppEngine.API.Health

  def init(_opts) do
    nil
  end

  def call(%{request_path: "/health", method: "GET"} = conn, _opts) do
    status = Health.get_health()

    if status in [:ready, :degraded] do
      log_health_telemetry(1)

      conn
      |> send_resp(:ok, "")
      |> halt()
    else
      log_health_telemetry(0)

      conn
      |> send_resp(:service_unavailable, "")
      |> halt()
    end
  rescue
    _ ->
      log_health_telemetry(0)

      conn
      |> send_resp(:internal_server_error, "")
      |> halt()
  end

  def call(conn, _opts) do
    conn
  end

  # helper for telemetry reporting
  defp log_health_telemetry(health_score) do
    for level <- [:quorum, :one] do
      :telemetry.execute(
        [:astarte, :appengine, :service],
        %{health: health_score},
        %{consistency_level: level}
      )
    end
  end
end
