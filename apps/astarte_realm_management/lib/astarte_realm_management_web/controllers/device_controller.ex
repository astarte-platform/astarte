#
# This file is part of Astarte.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Astarte.RealmManagementWeb.DeviceController do
  use Astarte.RealmManagementWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.RealmManagement.Devices
  alias OpenApiSpex.{Reference, Response}

  action_fallback Astarte.RealmManagementWeb.FallbackController

  tags ["device"]
  security [%{"JWT" => []}]

  operation :delete,
    summary: "Delete device",
    description: """
    Deletes an existing device with a given `device_id`.
    Device deletion happens asynchronously, and receiving a 204 response
    doesn't guarantee immediate deletion of the device.
    """,
    operation_id: "deleteDevice",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"},
      %Reference{"$ref": "#/components/parameters/DeviceID"}
    ],
    responses: [
      no_content: %Response{description: "Success"},
      bad_request: %Response{description: "Bad request"},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/NotFound"},
      internal_server_error: %Response{description: "Internal Server Error."}
    ]

  def delete(conn, %{"realm_name" => realm_name, "device_id" => device_id}) do
    with :ok <- Devices.delete_device(realm_name, device_id) do
      send_resp(conn, :no_content, "")
    end
  end
end
