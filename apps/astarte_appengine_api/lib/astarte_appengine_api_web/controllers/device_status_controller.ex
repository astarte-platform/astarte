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

defmodule Astarte.AppEngine.APIWeb.DeviceStatusController do
  use Astarte.AppEngine.APIWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.APIWeb.ApiSpec.Schemas.DeviceStatus, as: DeviceStatusSchema
  alias Astarte.AppEngine.APIWeb.ApiSpec.Schemas.Errors
  alias OpenApiSpex.{Reference, Schema}

  @devices_list_response_schema %Schema{
    type: :object,
    properties: %{
      data: %Schema{
        type: :array,
        items: %Schema{type: :string}
      },
      links: %Schema{
        type: :object,
        properties: %{
          self: %Schema{
            type: :string,
            format: :uri,
            description: "A relative link to this response."
          },
          next: %Schema{
            type: :string,
            format: :uri,
            description: "A relative link to next devices list page."
          }
        }
      }
    },
    example: %{
      links: %{
        self: "/v1/example/devices?limit=3",
        next: "/v1/example/devices?from_token=-2128516163519372076&limit=3"
      },
      data: [
        "hjnD0GrEP3o9ED1SUuL4QQ",
        "8ZxuSGkU7pggwoomJeXo9g",
        "k-IFKDPoVzIXUcFkF7U80A"
      ]
    }
  }

  @device_status_response_schema %Schema{
    type: :object,
    properties: %{
      data: DeviceStatusSchema
    }
  }

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  operation :index,
    summary: "Get devices list",
    description:
      "A paged list of all devices is returned. By default the device ID string is returned for each already registered device. The complete device status can be optionally retrieved rather than device ID string using details option.",
    operation_id: "getDevicesList",
    tags: ["device"],
    security: [%{"JWT" => []}],
    parameters: [
      realm_name: [
        in: :path,
        description: "The name of the realm the device list will be returned from.",
        required: true,
        type: :string
      ],
      from_token: [
        in: :query,
        description:
          "Opaque devices list page pointer: it basically points to the beginning of a devices page. If not specified the devices list is displayed from the beginning. This format might change in future versions so it should be passed without any further assumption about type, format or its value.",
        required: false,
        type: :integer
      ],
      limit: [
        in: :query,
        description: "Maximum number of devices that will be returned for each page.",
        required: false,
        schema: %Schema{type: :integer, minimum: 1, default: 1000}
      ],
      details: [
        in: :query,
        description:
          "If true detailed device status for all devices is returned rather than the device id. See also DeviceStatus example.",
        required: false,
        schema: %Schema{type: :boolean, default: false}
      ]
    ],
    responses: [
      ok: {"Devices list", "application/json", @devices_list_response_schema},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"}
    ]

  operation :show,
    summary: "Get device general status",
    description:
      "A device overview status is returned. Overview includes an array of reported interfaces (introspection), offline/online status, etc...",
    operation_id: "getDeviceStatus",
    tags: ["device"],
    security: [%{"JWT" => []}],
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm which the device belongs to.",
        required: true,
        type: :string
      ],
      device_id: [
        in: :path,
        description: "Device ID",
        required: true,
        type: :string
      ]
    ],
    responses: [
      ok: {"Success", "application/json", @device_status_response_schema},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      not_found: {"Device not found", "application/json", Errors.NotFoundError}
    ]

  operation :update,
    summary: "Update a device writeable property",
    description:
      "Update any of the writeable device properties such as device aliases, device attributes or credentials inhibited.",
    operation_id: "updateDeviceStatus",
    tags: ["device"],
    security: [%{"JWT" => []}],
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm which the device belongs to.",
        required: true,
        type: :string
      ],
      device_id: [
        in: :path,
        description: "Device ID",
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
      ok: {"Success", "application/json", @device_status_response_schema},
      bad_request: "Bad request",
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      not_found: {"Device not found.", "application/json", Errors.NotFoundError}
    ]

  def index(conn, %{"realm_name" => realm_name, "details" => "true"} = params) do
    with {:ok, %DevicesList{} = devices_list} <- Device.list_devices!(realm_name, params) do
      render(conn, "detailed_index.json", %{devices_list: devices_list, request: params})
    end
  end

  def index(conn, %{"realm_name" => realm_name} = params) do
    with {:ok, %DevicesList{} = devices_list} <- Device.list_devices!(realm_name, params) do
      render(conn, "index.json", %{devices_list: devices_list, request: params})
    end
  end

  def show(conn, %{"realm_name" => realm_name, "device_id" => id}) do
    with {:ok, %DeviceStatus{} = device_status} <- Device.get_device_status!(realm_name, id) do
      render(conn, "show.json", device_status: device_status)
    end
  end

  def update(%Plug.Conn{method: "PATCH"} = conn, %{
        "realm_name" => realm_name,
        "device_id" => id,
        "data" => data
      }) do
    # Here we handle merge/patch as described here https://tools.ietf.org/html/rfc7396
    if get_req_header(conn, "content-type") == ["application/merge-patch+json"] do
      with {:ok, %DeviceStatus{} = device_status} <-
             Device.merge_device_status(realm_name, id, data) do
        render(conn, "show.json", device_status: device_status)
      end
    else
      {:error, :patch_mimetype_not_supported}
    end
  end
end
