#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.RealmManagementWeb.RealmConfigController do
  use Astarte.RealmManagementWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.RealmManagement.RealmConfig
  alias Astarte.RealmManagement.RealmConfig.AuthConfig
  alias OpenApiSpex.{Reference, Schema}

  action_fallback Astarte.RealmManagementWeb.FallbackController

  tags ["config"]
  security [%{"JWT" => []}]

  operation :show_auth,
    summary: "Get auth configuration",
    description: "Get a JSON that describes the auth configuration of the realm",
    operation_id: "getAuthConfig",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"}
    ],
    responses: [
      ok: %Reference{"$ref": "#/components/responses/GetAuthConfig"},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"}
    ]

  operation :show_device_registration_limit,
    summary: "Get device registration limit",
    description: "Get the maximum number of devices that can be registered in the realm.",
    operation_id: "getDeviceRegistrationLimit",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"}
    ],
    responses: [
      ok: %Reference{"$ref": "#/components/responses/GetDeviceRegistrationLimit"},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/NotFound"}
    ]

  operation :show_datastream_maximum_storage_retention,
    summary: "Get datastream maximum storage retention",
    description:
      "Get the maximum storage retention for datastreams belonging to the realm, in seconds.",
    operation_id: "getDatastreamMaximumStorageRetention",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"}
    ],
    responses: [
      ok: %Reference{"$ref": "#/components/responses/GetDatastreamMaximumStorageRetention"},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/NotFound"}
    ]

  operation :update_auth,
    summary: "Install a new auth configuration for the realm",
    description: """
    Installs a auth configuration for the realm. The body must contain the
    full auth configuration. Validation is performed, and an error is
    returned if the configuration cannot be installed or validated.
    """,
    operation_id: "putAuthConfig",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"}
    ],
    request_body: {
      "AuthConfig object with the new configuration",
      "application/json",
      %Schema{
        type: :object,
        required: [:data],
        properties: %{
          data: %Reference{"$ref": "#/components/schemas/AuthConfig"}
        }
      },
      required: true
    },
    responses: [
      no_content: {"Success", nil, nil},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/ConfigValidationError"}
    ]

  def show_auth(conn, %{"realm_name" => realm_name}) do
    with {:ok, %AuthConfig{} = auth_config} <- RealmConfig.get_auth_config(realm_name) do
      render(conn, "show.json", auth_config: auth_config)
    end
  end

  def show_device_registration_limit(conn, %{"realm_name" => realm_name}) do
    with {:ok, device_registration_limit} <-
           RealmConfig.get_device_registration_limit(realm_name) do
      render(conn, "show.json", device_registration_limit: device_registration_limit)
    end
  end

  def show_datastream_maximum_storage_retention(conn, %{"realm_name" => realm_name}) do
    with {:ok, datastream_maximum_storage_retention} <-
           RealmConfig.get_datastream_maximum_storage_retention(realm_name) do
      render(conn, "show.json",
        datastream_maximum_storage_retention: datastream_maximum_storage_retention
      )
    end
  end

  def update_auth(conn, %{"realm_name" => realm_name, "data" => new_config}) do
    with :ok <- RealmConfig.update_auth_config(realm_name, new_config) do
      send_resp(conn, :no_content, "")
    end
  end
end
