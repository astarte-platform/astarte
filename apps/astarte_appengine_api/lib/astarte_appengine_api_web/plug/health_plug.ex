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

defmodule Astarte.AppEngine.APIWeb.HealthPlug do
  @behaviour Plug
  import Plug.Conn

  alias Astarte.AppEngine.API.Health

  def init(_opts) do
    nil
  end

  def call(%{request_path: "/health", method: "GET"} = conn, _opts) do
    try do
      status =
        case Health.get_health() do
          :ok ->
            :telemetry.execute(
              [:astarte, :appengine, :service],
              %{health: 1},
              %{consistency_level: :quorum}
            )

            :telemetry.execute(
              [:astarte, :appengine, :service],
              %{health: 1},
              %{consistency_level: :one}
            )

            :ok

          {:error, :degraded_health} ->
            :telemetry.execute(
              [:astarte, :appengine, :service],
              %{health: 0},
              %{consistency_level: :quorum}
            )

            :telemetry.execute(
              [:astarte, :appengine, :service],
              %{health: 1},
              %{consistency_level: :one}
            )

            :ok

          _ ->
            :telemetry.execute(
              [:astarte, :appengine, :service],
              %{health: 0},
              %{consistency_level: :quorum}
            )

            :telemetry.execute(
              [:astarte, :appengine, :service],
              %{health: 0},
              %{consistency_level: :one}
            )

            :service_unavailable
        end

      conn
      |> send_resp(status, "")
      |> halt()
    rescue
      _ ->
        :telemetry.execute(
          [:astarte, :appengine, :service],
          %{health: 0},
          %{consistency_level: :quorum}
        )

        :telemetry.execute(
          [:astarte, :appengine, :service],
          %{health: 0},
          %{consistency_level: :one}
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
