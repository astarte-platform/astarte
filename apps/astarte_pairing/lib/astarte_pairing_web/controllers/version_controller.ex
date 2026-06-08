#
# This file is part of Astarte.
#
# Copyright 2021 Ispirata Srl
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

defmodule Astarte.PairingWeb.VersionController do
  use Astarte.PairingWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema

  @version Mix.Project.config()[:version]

  tags ["version"]

  operation :show,
    summary: "Retrieve API version",
    description:
      "Return the Pairing API version. This endpoint is available at {base_url}/version (without /v1).",
    operation_id: "getVersion",
    responses: [
      ok:
        {"Success", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :string, example: "1.3.0"}
           }
         }}
    ]

  operation :show_with_realm,
    summary: "Retrieve API version",
    description: "Return the Pairing API version.",
    operation_id: "getVersionWithRealm",
    security: [%{"JWT" => []}],
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm.",
        type: :string,
        required: true
      ]
    ],
    responses: [
      ok:
        {"Success", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :string, example: "1.3.0"}
           }
         }}
    ]

  def show(conn, _params) do
    render(conn, "show.json", %{version: @version})
  end

  def show_with_realm(conn, _params) do
    render(conn, "show.json", %{version: @version})
  end
end
