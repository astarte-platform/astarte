#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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
defmodule Astarte.AppEngine.APIWeb.DeviceStatusByGroupController do
  use Astarte.AppEngine.APIWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Groups
  alias Astarte.AppEngine.APIWeb.ApiSpec.Schemas.DeviceStatus, as: DeviceStatusSchema
  alias Astarte.AppEngine.APIWeb.DeviceStatusView
  alias OpenApiSpex.{Reference, Schema}

  @device_status_response_schema %Schema{
    type: :object,
    properties: %{
      data: DeviceStatusSchema
    }
  }

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  tags ["groups"]
  security [%{"JWT" => []}]

  operation :index,
    summary: "List devices in a group",
    description: "Return the list of devices in a group.",
    operation_id: "indexGroupDevices",
    parameters: [
      realm_name: [
        in: :path,
        description: "The name of the realm the device list will be returned from.",
        required: true,
        type: :string
      ],
      group_name: [
        in: :path,
        description: "The name of the group.",
        required: true,
        type: :string
      ]
    ],
    responses: [
      ok: %Reference{"$ref": "#/components/responses/IndexGroupDevices"},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      not_found: %Reference{"$ref": "#/components/responses/GroupNotFound"}
    ]

  operation :show,
    summary: "Get device general status",
    description: "Return the status of a device that belongs to a group.",
    operation_id: "getGroupDeviceStatus",
    parameters: [
      realm_name: [
        in: :path,
        description: "The name of the realm the device belongs to.",
        required: true,
        type: :string
      ],
      group_name: [
        in: :path,
        description: "The name of the group.",
        required: true,
        type: :string
      ],
      device_id: [in: :path, description: "Device ID", required: true, type: :string]
    ],
    responses: [
      ok: {"Success", "application/json", @device_status_response_schema},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      not_found: %Reference{"$ref": "#/components/responses/GroupOrDeviceNotFound"}
    ]

  operation :update,
    summary: "Update a device writeable property",
    description:
      "Update any of the writeable device properties for a device that belongs to a group.",
    operation_id: "updateGroupDeviceStatus",
    parameters: [
      realm_name: [
        in: :path,
        description: "The name of the realm the device belongs to.",
        required: true,
        type: :string
      ],
      group_name: [
        in: :path,
        description: "The name of the group.",
        required: true,
        type: :string
      ],
      device_id: [in: :path, description: "Device ID", required: true, type: :string]
    ],
    request_body: {
      "A JSON Merge Patch containing the property changes which should be applied to the device.",
      "application/merge-patch+json",
      %Schema{type: :object}
    },
    responses: [
      ok: {"Success", "application/json", @device_status_response_schema},
      bad_request: "Bad request",
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      not_found: %Reference{"$ref": "#/components/responses/GroupOrDeviceNotFound"}
    ]

  def index(
        conn,
        %{"realm_name" => realm_name, "group_name" => group_name, "details" => "true"} = params
      ) do
    with {:ok, %DevicesList{} = devices_list} <-
           Groups.list_detailed_devices(realm_name, group_name, params) do
      render(conn, "detailed_index.json", devices_list: devices_list, request: params)
    end
  end

  def index(conn, %{"realm_name" => realm_name, "group_name" => group_name} = params) do
    with {:ok, %DevicesList{} = devices_list} <-
           Groups.list_devices(realm_name, group_name, params) do
      render(conn, "index.json", devices_list: devices_list, request: params)
    end
  end

  def show(conn, %{
        "realm_name" => realm_name,
        "group_name" => group_name,
        "device_id" => device_id
      }) do
    with {:ok, true} <- Groups.check_device_in_group(realm_name, group_name, device_id),
         {:ok, device_status} <- Device.get_device_status!(realm_name, device_id) do
      conn
      |> put_view(DeviceStatusView)
      |> render("show.json", device_status: device_status)
    else
      {:ok, false} ->
        {:error, :device_not_found}

      {:error, reason} ->
        # To FallbackController
        {:error, reason}
    end
  end

  def update(%Plug.Conn{method: "PATCH"} = conn, %{
        "realm_name" => realm_name,
        "group_name" => group_name,
        "device_id" => device_id,
        "data" => data
      }) do
    # Here we handle merge/patch as described here https://tools.ietf.org/html/rfc7396
    if get_req_header(conn, "content-type") == ["application/merge-patch+json"] do
      with {:ok, true} <- Groups.check_device_in_group(realm_name, group_name, device_id),
           {:ok, %DeviceStatus{} = device_status} <-
             Device.merge_device_status(realm_name, device_id, data) do
        conn
        |> put_view(DeviceStatusView)
        |> render("show.json", device_status: device_status)
      else
        {:ok, false} ->
          {:error, :device_not_found}

        {:error, reason} ->
          # To FallbackController
          {:error, reason}
      end
    else
      {:error, :patch_mimetype_not_supported}
    end
  end
end
