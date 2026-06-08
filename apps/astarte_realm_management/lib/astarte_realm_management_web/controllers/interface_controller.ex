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

defmodule Astarte.RealmManagementWeb.InterfaceController do
  use Astarte.RealmManagementWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.Core.Interface
  alias Astarte.RealmManagement.Interfaces
  alias OpenApiSpex.{Reference, Schema}

  action_fallback Astarte.RealmManagementWeb.FallbackController

  tags ["interface"]
  security [%{"JWT" => []}]

  operation :index,
    summary: "Get interface list",
    description: """
    Get a list of all installed interface names.
    """,
    operation_id: "getInterfaceList",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"}
    ],
    responses: [
      ok: %Reference{"$ref": "#/components/responses/GetInterfaceList"},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"}
    ]

  operation :create,
    summary: "Install a new interface to the realm",
    description: """
    Install a new interface, or a newer major version for a given interface.
    Validation is performed, and an error is returned if interface cannot be
    installed. The installation is performed asynchronously by default. You
    can perform the call synchronously by setting the async_operation query
    param to false.
    """,
    operation_id: "installInterface",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"},
      async_operation: [
        in: :query,
        description: "Whether the operation should be carried out asynchronously.",
        required: false,
        schema: %Schema{type: :boolean, default: true}
      ]
    ],
    request_body: {
      "A JSON object representing an Astarte Interface.",
      "application/json",
      %Schema{
        type: :object,
        required: [:data],
        properties: %{
          data: %Reference{"$ref": "#/components/schemas/Interface"}
        }
      },
      required: true
    },
    responses: [
      created: %Reference{"$ref": "#/components/responses/InstallInterface"},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/InterfaceValidationError"}
    ]

  operation :show,
    summary: "Get an interface",
    description: """
    Show a previously installed interface. Previous minor versions for a
    given major version are not retrieved, only the most recent interface
    for each interface major is returned.
    """,
    operation_id: "getInterface",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"},
      %Reference{"$ref": "#/components/parameters/InterfaceName"},
      %Reference{"$ref": "#/components/parameters/InterfaceMajor"}
    ],
    responses: [
      ok: %Reference{"$ref": "#/components/responses/GetInterface"},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/InterfaceNotFound"}
    ]

  operation :update,
    summary: "Updates an existing interface to a new minor release",
    description: """
    Replace an existing interface with a certain major version with a new
    one (that must have same major version and a higher minor version).
    Server side validation is performed. Interface upgrade is performed
    asynchronously by default. You can perform the call synchronously by
    setting the async_operation query param to false. For more information
    about what is allowed when updating an interface, see [the
    doc](https://docs.astarte-platform.org/astarte/1.0/030-interface.html#versioning).
    This operation cannot be reverted.
    """,
    operation_id: "updateInterface",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"},
      %Reference{"$ref": "#/components/parameters/InterfaceName"},
      %Reference{"$ref": "#/components/parameters/InterfaceMajor"},
      async_operation: [
        in: :query,
        description: "Whether the operation should be carried out asynchronously.",
        required: false,
        schema: %Schema{type: :boolean, default: true}
      ]
    ],
    request_body: {
      "A JSON object representing the updated Astarte Interface.",
      "application/json",
      %Schema{
        type: :object,
        required: [:data],
        properties: %{
          data: %Reference{"$ref": "#/components/schemas/Interface"}
        }
      },
      required: true
    },
    responses: [
      no_content: {"Success", nil, nil},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/InterfaceNotFound"},
      conflict: %Reference{"$ref": "#/components/responses/UpdateConflict"},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/InterfaceValidationError"}
    ]

  operation :delete,
    summary: "Delete a draft interface",
    description: """
    Delete an interface draft (a draft is an interface with major version
    0). An interface with a major version different than 0 should be
    manually deleted. Interface deletion is performed asynchronously by
    default. You can perform the call synchronously by setting the
    async_operation query param to false.
    """,
    operation_id: "deleteInterface",
    parameters: [
      %Reference{"$ref": "#/components/parameters/Realm"},
      %Reference{"$ref": "#/components/parameters/InterfaceName"},
      %Reference{"$ref": "#/components/parameters/InterfaceMajor"},
      async_operation: [
        in: :query,
        description: "Whether the operation should be carried out asynchronously.",
        required: false,
        schema: %Schema{type: :boolean, default: true}
      ]
    ],
    responses: [
      no_content: {"Success", nil, nil},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/Forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/InterfaceNotFound"}
    ]

  def index(conn, %{"realm_name" => realm_name}) do
    with {:ok, interfaces} <- Interfaces.list_interfaces(realm_name) do
      render(conn, "index.json", interfaces: interfaces)
    end
  end

  def create(conn, %{"realm_name" => realm_name, "data" => %{} = interface_params} = params) do
    async_operation =
      if Map.get(params, "async_operation") == "false" do
        false
      else
        true
      end

    case Interfaces.install_interface(realm_name, interface_params, async: async_operation) do
      {:ok, %Interface{} = interface} ->
        location =
          interface_path(
            conn,
            :show,
            realm_name,
            interface.name,
            Integer.to_string(interface.major_version)
          )

        conn
        |> put_resp_header("location", location)
        |> send_resp(:created, "")

      {:error, :already_installed_interface = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      {:error, :interface_name_collision = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      {:error, other} ->
        {:error, other}
    end
  end

  def show(conn, %{
        "realm_name" => realm_name,
        "interface_name" => interface_name,
        "major_version" => major_version
      }) do
    with {:major_parsing, {parsed_major, ""}} <- {:major_parsing, Integer.parse(major_version)},
         {:ok, interface_source} <-
           Interfaces.fetch_interface(realm_name, interface_name, parsed_major) do
      render(conn, "show.json", interface: interface_source)
    else
      {:major_parsing, _} ->
        {:error, :invalid_major}

      # To FallbackController
      {:error, other} ->
        {:error, other}
    end
  end

  def update(
        conn,
        %{
          "realm_name" => realm_name,
          "interface_name" => interface_name,
          "major_version" => major_version,
          "data" => %{} = interface_params
        } = params
      ) do
    async_operation =
      if Map.get(params, "async_operation") == "false" do
        false
      else
        true
      end

    with {:major_parsing, {parsed_major, ""}} <- {:major_parsing, Integer.parse(major_version)},
         :ok <-
           Interfaces.update_interface(realm_name, interface_name, parsed_major, interface_params,
             async_operation: async_operation
           ) do
      send_resp(conn, :no_content, "")
    else
      {:major_parsing, _} ->
        {:error, :invalid_major}

      # API side errors
      {:error, :name_not_matching = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      {:error, :major_version_not_matching = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      # Backend side errors
      {:error, :interface_major_version_does_not_exist = err_atom} ->
        conn
        |> put_status(:not_found)
        |> render(err_atom)

      {:error, :minor_version_not_increased = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      {:error, :invalid_update = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      {:error, :downgrade_not_allowed = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      {:error, :missing_endpoints = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      {:error, :incompatible_endpoint_change = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      # Let FallbackController handle the rest
      {:error, other} ->
        {:error, other}
    end
  end

  def delete(
        conn,
        %{
          "realm_name" => realm_name,
          "interface_name" => interface_name,
          "major_version" => major_version
        } = params
      ) do
    {parsed_major, ""} = Integer.parse(major_version)

    async_operation = Map.get(params, "async_operation") != "false"

    case Interfaces.delete_interface(
           realm_name,
           interface_name,
           parsed_major,
           async_operation: async_operation
         ) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> render(:delete_forbidden)

      {:error, :cannot_delete_currently_used_interface = err_atom} ->
        conn
        |> put_status(:forbidden)
        |> render(err_atom)

      # To FallbackController
      {:error, other} ->
        {:error, other}
    end
  end
end
