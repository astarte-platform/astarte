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

defmodule Astarte.AppEngine.APIWeb.InterfaceValuesByGroupController do
  use Astarte.AppEngine.APIWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.AppEngine.API.Groups
  alias Astarte.AppEngine.APIWeb.ApiSpec.Schemas.Errors
  alias Astarte.AppEngine.APIWeb.InterfaceValuesView
  alias OpenApiSpex.{Reference, Schema}

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  tags ["groups"]
  security [%{"JWT" => []}]

  operation :index,
    summary: "Get interfaces list for device in a group",
    description:
      "Get a list of interfaces supported by a certain device that belongs to a group. Interfaces that are not reported by the device are not reported here. If a device stops to advertise a certain interface, it should be retrieved from a different API, same applies for older versions of a certain interface.",
    operation_id: "getGroupDeviceInterfaces",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm which the device belongs to.",
        required: true,
        type: :string
      ],
      group_name: [in: :path, description: "Group name", required: true, type: :string],
      device_id: [in: :path, description: "Device ID", required: true, type: :string]
    ],
    responses: [
      ok:
        {"Success", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{
               type: :array,
               items: %Schema{type: :string},
               example: ["com.test.foo", "com.test.bar"]
             }
           }
         }},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      not_found: {"Device not found.", "application/json", Errors.NotFoundError}
    ]

  operation :show_value,
    summary: "Get property value for device in a group",
    description:
      "Retrieve a value on a given path for a device that belongs to a group. This action on a data production path returns the last entry if no query parameters are specified.",
    operation_id: "getGroupDeviceInterfacePropertyValue",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm which the device belongs to.",
        required: true,
        type: :string
      ],
      group_name: [in: :path, description: "Group name", required: true, type: :string],
      device_id: [in: :path, description: "Device ID", required: true, type: :string],
      interface: [in: :path, description: "Interface name", required: true, type: :string],
      path: [in: :path, description: "Endpoint Path", required: true, type: :string],
      since: [
        in: :query,
        description:
          "Query all values since a certain timestamp (all entries where timestamp >= since). This query parameter applies only on data streams. It must be a ISO 8601 valid timestamp. It can't be used if since is already used. See also 'since_after', to' and 'limit' parameters.",
        required: false,
        type: :string
      ],
      since_after: [
        in: :query,
        description:
          "Query all values since after a certain timestamp (all entries where timestamp > since_after). This query parameter applies only on data streams. It must be a ISO 8601 valid timestamp. It can't be used if since is already specified. See also 'since', 'to' and 'limit' parameters.",
        required: false,
        type: :string
      ],
      to: [
        in: :query,
        description:
          "Query all values up to a certain timestamp. If since is not specified first entry date is assumed by default. This query parameter applies only on data streams. It must be a ISO 8601 valid timestamp. See also 'since' and 'limit' parameters.",
        required: false,
        type: :string
      ],
      limit: [
        in: :query,
        description:
          "Limit number of retrieved data production entries to 'limit'. This parameter must be always specified when 'since', 'since-after' and 'to' query parameters are used. If limit is specified without any 'since' and 'to' parameter, last 'limit' values are retrieved. When 'limit' entries are returned, it should be checked if any other entry is left by using since-after the last received timestamp. An error is returned if limit exceeds maximum allowed value. See also 'since' and 'to' parameters.",
        required: false,
        type: :string
      ]
    ],
    responses: [
      ok: "Success",
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      not_found:
        {"Path not found or interface not found in introspection or device not found.",
         "application/json", Errors.NotFoundError},
      method_not_allowed: "Invalid Request"
    ]

  operation :show_values,
    summary: "Get properties values for device in a group",
    description:
      "Get a values snapshot for a given interface on a certain device that belongs to a group. This action performed on a data stream interface returns the most recent set of data for each endpoint. More specific APIs should be used for advanced data stream actions.",
    operation_id: "getGroupDeviceInterfacePropertiesValues",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm which the device belongs to.",
        required: true,
        type: :string
      ],
      group_name: [in: :path, description: "Group name", required: true, type: :string],
      device_id: [in: :path, description: "Device ID", required: true, type: :string],
      interface: [in: :path, description: "Interface name", required: true, type: :string]
    ],
    responses: [
      ok: "Success",
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      not_found:
        {"Interface not found in introspection or device not found.", "application/json",
         Errors.NotFoundError}
    ]

  operation :update,
    summary: "Update and push a value on a path for device in a group",
    description:
      "Update and push a property value to the device on a certain endpoint path. interface should be an individual server owned property interface. It mustn't be used to stream data to a device or to update single properties that are members of an object aggregated interface.",
    operation_id: "updateGroupDevicePathValue",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm which the device belongs to.",
        required: true,
        type: :string
      ],
      group_name: [in: :path, description: "Group name", required: true, type: :string],
      device_id: [in: :path, description: "Device ID", required: true, type: :string],
      interface: [in: :path, description: "Interface name", required: true, type: :string],
      path: [in: :path, description: "Endpoint Path", required: true, type: :string]
    ],
    responses: [
      ok: "Success",
      bad_request: "Bad request",
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      not_found:
        {"Endpoint not found or interface not found in introspection or device not found.",
         "application/json", Errors.NotFoundError},
      method_not_allowed: "Invalid object",
      unprocessable_entity: "Tried to unset a property with `allow_unset` false"
    ]

  operation :delete,
    summary: "Delete path and push an unset value message for device in a group",
    description:
      "Unset a value on a certain path, path is also deleted. Endpoint must support unset.",
    operation_id: "deleteGroupDevicePathValue",
    parameters: [
      realm_name: [
        in: :path,
        description: "Name of the realm which the device belongs to.",
        required: true,
        type: :string
      ],
      group_name: [in: :path, description: "Group name", required: true, type: :string],
      device_id: [in: :path, description: "Device ID", required: true, type: :string],
      interface: [in: :path, description: "Interface name", required: true, type: :string],
      path: [in: :path, description: "Endpoint Path", required: true, type: :string]
    ],
    responses: [
      no_content: "Success",
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      not_found:
        {"Path not found or interface not found in introspection or device not found.",
         "application/json", Errors.NotFoundError}
    ]

  def index(conn, %{
        "realm_name" => realm_name,
        "group_name" => group_name,
        "device_id" => device_id
      }) do
    with {:ok, true} <- Groups.check_device_in_group(realm_name, group_name, device_id),
         {:ok, interfaces} <- Device.list_interfaces(realm_name, device_id) do
      conn
      |> put_view(InterfaceValuesView)
      |> render("index.json", interfaces: interfaces)
    else
      {:ok, false} ->
        {:error, :device_not_found}

      {:error, reason} ->
        # To FallbackController
        {:error, reason}
    end
  end

  def show_value(conn, parameters) do
    do_show(conn, parameters)
  end

  def show_values(conn, parameters) do
    do_show(conn, parameters)
  end

  defp do_show(
         conn,
         %{
           "realm_name" => realm_name,
           "group_name" => group_name,
           "device_id" => device_id,
           "interface" => interface,
           "path" => path
         } = parameters
       ) do
    with {:ok, true} <- Groups.check_device_in_group(realm_name, group_name, device_id),
         {:ok, %InterfaceValues{} = interface_values} <-
           Device.get_interface_values!(
             realm_name,
             device_id,
             interface,
             path,
             parameters
           ) do
      conn
      |> put_view(InterfaceValuesView)
      |> render("show.json", interface_values: interface_values)
    else
      {:ok, false} ->
        {:error, :device_not_found}

      {:error, reason} ->
        # To FallbackController
        {:error, reason}
    end
  end

  defp do_show(
         conn,
         %{
           "realm_name" => realm_name,
           "group_name" => group_name,
           "device_id" => device_id,
           "interface" => interface
         } = parameters
       ) do
    with {:ok, true} <- Groups.check_device_in_group(realm_name, group_name, device_id),
         {:ok, %InterfaceValues{} = interface_values} <-
           Device.get_interface_values!(
             realm_name,
             device_id,
             interface,
             parameters
           ) do
      conn
      |> put_view(InterfaceValuesView)
      |> render("show.json", interface_values: interface_values)
    else
      {:ok, false} ->
        {:error, :device_not_found}

      {:error, reason} ->
        # To FallbackController
        {:error, reason}
    end
  end

  def update(
        conn,
        %{
          "realm_name" => realm_name,
          "group_name" => group_name,
          "device_id" => device_id,
          "interface" => interface,
          "path" => path,
          "data" => value
        } = parameters
      ) do
    with {:ok, true} <- Groups.check_device_in_group(realm_name, group_name, device_id),
         {:ok, %InterfaceValues{} = interface_values} <-
           Device.update_interface_values(
             realm_name,
             device_id,
             interface,
             path,
             value,
             parameters
           ) do
      conn
      |> put_view(InterfaceValuesView)
      |> render("show.json", interface_values: interface_values)
    else
      {:ok, false} ->
        {:error, :device_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def delete(conn, %{
        "realm_name" => realm_name,
        "group_name" => group_name,
        "device_id" => device_id,
        "interface" => interface,
        "path" => path
      }) do
    with {:ok, true} <- Groups.check_device_in_group(realm_name, group_name, device_id),
         :ok <- Device.delete_interface_values(realm_name, device_id, interface, path) do
      send_resp(conn, :no_content, "")
    else
      {:ok, false} ->
        {:error, :device_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
