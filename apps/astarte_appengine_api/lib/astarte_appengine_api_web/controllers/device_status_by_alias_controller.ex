#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.AppEngine.APIWeb.DeviceStatusByAliasController do
  use Astarte.AppEngine.APIWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.APIWeb.ApiSpec.Schemas.DeviceStatusByAlias
  alias Astarte.AppEngine.APIWeb.ApiSpec.Schemas.Errors
  alias Astarte.AppEngine.APIWeb.DeviceStatusView
  alias OpenApiSpex.{Reference, Schema}

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  tags ["device"]
  security [%{"JWT" => []}]

  operation :index,
    summary: "List devices by alias",
    description:
      "Device listing by alias is not supported. This endpoint is exposed for compatibility and returns an error.",
    operation_id: "getDevicesListByAlias",
    parameters: [
      realm_name: [
        in: :path,
        description: "The name of the realm the device list would be returned from.",
        required: true,
        type: :string
      ]
    ],
    responses: [
      method_not_allowed:
        {"Devices listing by alias is not allowed.", "application/json", Errors.UnauthorizedError},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden:
        {"Authorization path not matched.", "application/json",
         Errors.AuthorizationPathNotMatchedError}
    ]

  operation :show,
    summary: "Get device general status",
    description:
      "A device overview status is returned. Overview includes an array of reported interfaces (introspection), offline/online status, etc...",
    operation_id: "getDeviceStatusByAlias",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm which the device belongs to.",
        required: true,
        type: :string
      ],
      device_alias: [
        in: :path,
        description: "One of the device aliases",
        required: true,
        type: :string
      ]
    ],
    responses: [
      ok: {"Success", "application/json", DeviceStatusByAlias},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden:
        {"Authorization path not matched.", "application/json",
         Errors.AuthorizationPathNotMatchedError},
      not_found: {"Device not found", "application/json", Errors.NotFoundError}
    ]

  operation :update,
    summary: "Update a device writeable property",
    description:
      "Update any of the writeable device properties such as device aliases, device attributes or credentials inhibited.",
    operation_id: "updateDeviceStatusByAlias",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm which the device belongs to.",
        required: true,
        type: :string
      ],
      device_alias: [
        in: :path,
        description: "One of the device aliases",
        required: true,
        type: :string
      ]
    ],
    request_body: {
      "A JSON Merge Patch containing the property changes which should be applied to the device.",
      "application/merge-patch+json",
      %Schema{type: :object}
    },
    responses: [
      ok: {"Success", "application/json", DeviceStatusByAlias},
      bad_request: "Bad request",
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden:
        {"Authorization path not matched.", "application/json",
         Errors.AuthorizationPathNotMatchedError},
      not_found: {"Device not found.", "application/json", Errors.NotFoundError}
    ]

  # TODO: should we allow to POST/create device aliases here by posting something
  # like a DeviceAlias JSON object?
  # def create(conn, %{"device_status_by_alias" => device_status_by_alias_params})

  def index(_conn, _params) do
    {:error, :devices_listing_by_alias_not_allowed}
  end

  def show(conn, %{"realm_name" => realm_name, "device_alias" => device_alias}) do
    with {:ok, device_id} <- Device.device_alias_to_device_id(realm_name, device_alias),
         encoded_device_id <- Base.url_encode64(device_id, padding: false),
         {:ok, device_status_by_alias} <-
           Device.get_device_status!(realm_name, encoded_device_id) do
      conn
      |> put_view(DeviceStatusView)
      |> render("show.json", device_status: device_status_by_alias)
    end
  end

  def update(%Plug.Conn{method: "PATCH"} = conn, %{
        "realm_name" => realm_name,
        "id" => device_alias,
        "data" => data
      }) do
    # Here we handle merge/patch as described here https://tools.ietf.org/html/rfc7396
    if get_req_header(conn, "content-type") == ["application/merge-patch+json"] do
      with {:ok, device_id} <- Device.device_alias_to_device_id(realm_name, device_alias),
           encoded_device_id <- Base.url_encode64(device_id, padding: false),
           {:ok, %DeviceStatus{} = device_status} <-
             Device.merge_device_status(realm_name, encoded_device_id, data) do
        conn
        |> put_view(DeviceStatusView)
        |> render("show.json", device_status: device_status)
      end
    else
      {:error, :patch_mimetype_not_supported}
    end
  end
end
