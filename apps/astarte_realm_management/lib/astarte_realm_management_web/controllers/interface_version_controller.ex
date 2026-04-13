#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.RealmManagementWeb.InterfaceVersionController do
  use Astarte.RealmManagementWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.RealmManagement.Interfaces
  alias OpenApiSpex.Reference

  action_fallback Astarte.RealmManagementWeb.FallbackController

  tags ["interface"]
  security [%{"JWT" => []}]

  operation :index,
    summary: "Get interface major versions",
    description: "An interface might have multiple major versions, list all of them.",
    operation_id: "getInterfaceMajorVersions",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"},
      %Reference{"$ref": "#/components/parameters/InterfaceName"}
    ],
    responses: [
      ok: %Reference{"$ref": "#/components/responses/GetInterfaceMajorVersions"},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/InterfaceNotFound"}
    ]

  def index(conn, %{"realm_name" => realm_name, "interface_name" => interface_name}) do
    with {:ok, interfaces} <-
           Interfaces.list_interface_major_versions(realm_name, interface_name) do
      render(conn, "index.json", interfaces: interfaces)
    end
  end
end
