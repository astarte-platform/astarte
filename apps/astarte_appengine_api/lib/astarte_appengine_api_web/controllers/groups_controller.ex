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

defmodule Astarte.AppEngine.APIWeb.GroupsController do
  use Astarte.AppEngine.APIWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.AppEngine.API.Groups
  alias Astarte.DataAccess.Groups.Group
  alias OpenApiSpex.Reference

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  tags ["groups"]
  security [%{"JWT" => []}]

  operation :index,
    summary: "Get groups list",
    description: "Return the list of device groups that exist in the realm.",
    operation_id: "indexGroups",
    parameters: [
      %Reference{"$ref": "#/components/parameters/RealmName"}
    ],
    responses: [
      ok: %Reference{"$ref": "#/components/responses/IndexGroups"},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"}
    ]

  operation :create,
    summary: "Create new group",
    description:
      "Create a new group with a set of devices. Devices must already be registered in the realm.",
    operation_id: "createGroup",
    parameters: [
      %Reference{"$ref": "#/components/parameters/RealmName"}
    ],
    request_body: %Reference{"$ref": "#/components/requestBodies/CreateGroup"},
    responses: [
      created: %Reference{"$ref": "#/components/responses/GroupCreated"},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/InvalidGroupConfig"}
    ]

  operation :show,
    summary: "Get group config",
    description:
      "Return the configuration of the group. Currently, it just returns the group name, but the call can be used to verify if a group exists.",
    operation_id: "getGroupConfig",
    parameters: [
      %Reference{"$ref": "#/components/parameters/RealmName"},
      %Reference{"$ref": "#/components/parameters/GroupName"}
    ],
    responses: [
      ok: %Reference{"$ref": "#/components/responses/GetGroup"},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      not_found: %Reference{"$ref": "#/components/responses/GroupNotFound"}
    ]

  operation :add_device,
    summary: "Add device to group",
    description: "Add an existing device to a group.",
    operation_id: "addDeviceToGroup",
    parameters: [
      %Reference{"$ref": "#/components/parameters/RealmName"},
      %Reference{"$ref": "#/components/parameters/GroupName"}
    ],
    request_body: %Reference{"$ref": "#/components/requestBodies/AddDeviceToGroup"},
    responses: [
      created: "Success",
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      not_found: %Reference{"$ref": "#/components/responses/GroupNotFound"},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/InvalidAddGroup"}
    ]

  operation :remove_device,
    summary: "Remove device from group",
    description: "Remove device from group",
    operation_id: "removeDeviceFromGroup",
    parameters: [
      %Reference{"$ref": "#/components/parameters/RealmName"},
      %Reference{"$ref": "#/components/parameters/GroupName"},
      %Reference{"$ref": "#/components/parameters/DeviceId"}
    ],
    responses: [
      no_content: "Device removed",
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      not_found: %Reference{"$ref": "#/components/responses/GroupOrDeviceNotFound"}
    ]

  def index(conn, %{"realm_name" => realm_name}) do
    groups = Groups.list_groups(realm_name)
    render(conn, "index.json", groups: groups)
  end

  def create(conn, %{"realm_name" => realm_name, "data" => params}) do
    with {:ok, %Group{} = group} <- Groups.create_group(realm_name, params) do
      conn
      |> put_status(:created)
      |> render("create.json", group: group)
    end
  end

  def show(conn, %{"realm_name" => realm_name, "group_name" => group_name}) do
    with {:ok, group} <- Groups.get_group(realm_name, group_name) do
      render(conn, "show.json", group: group)
    end
  end

  def add_device(conn, %{"realm_name" => realm_name, "group_name" => group_name, "data" => params}) do
    with :ok <- Groups.add_device(realm_name, group_name, params) do
      send_resp(conn, :created, "")
    end
  end

  def remove_device(conn, %{
        "realm_name" => realm_name,
        "group_name" => group_name,
        "device_id" => device_id
      }) do
    with :ok <- Groups.remove_device(realm_name, group_name, device_id) do
      send_resp(conn, :no_content, "")
    end
  end
end
