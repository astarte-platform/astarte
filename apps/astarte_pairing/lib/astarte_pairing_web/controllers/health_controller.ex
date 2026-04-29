#
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

defmodule Astarte.PairingWeb.HealthController do
  use Astarte.PairingWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.Pairing.Health

  tags ["health"]

  operation :show,
    summary: "Retrieve API health",
    description: "Return the health status of the Pairing API.",
    operation_id: "getHealth",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm.",
        type: :string,
        required: true
      ]
    ],
    responses: [
      ok: {"Success", nil, nil},
      service_unavailable: {"Service unavailable", nil, nil}
    ]

  def show(conn, _params) do
    send_health(conn)
  end

  def send_health(conn) do
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
end
