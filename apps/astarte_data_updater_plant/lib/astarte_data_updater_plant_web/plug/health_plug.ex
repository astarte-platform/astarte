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

defmodule Astarte.DataUpdaterPlantWeb.HealthPlug do
  import Plug.Conn

  alias Astarte.DataUpdaterPlant.Health.Health

  def init(_args), do: nil

  def call(%{request_path: "/health", method: "GET"} = conn, _opts) do
    case Health.get_health() do
      :ready ->
        conn
        |> send_resp(:ok, "")
        |> halt()

      :bad ->
        conn
        |> send_resp(:service_unavailable, "")
        |> halt()
    end
  end

  def call(conn, _opts), do: conn
end
