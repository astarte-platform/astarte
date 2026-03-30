#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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

defmodule Astarte.HousekeepingWeb.RealmController do
  use Astarte.HousekeepingWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Astarte.Housekeeping.Realms
  alias Astarte.Housekeeping.Realms.Realm
  alias OpenApiSpex.{Reference, Schema}

  action_fallback Astarte.HousekeepingWeb.FallbackController

  tags(["realm"])
  security([%{"JWT" => []}])

  operation :index,
    summary: "Get all realms",
    description: "Returns a list of all existing realms.",
    operation_id: "getRealms",
    responses: [
      created:
        {"Success", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{
               type: :array,
               items: %Schema{type: :string}
             }
           },
           example: %{
             data: ["arealm", "anotherrealm"]
           }
         }}
    ]

  operation :create,
    summary: "Create a realm",
    description: "Creates a new realm, based on the provided realm configuration.
        Realm creation will be executed asynchronously by default - it is not
        guaranteed that the requested realm will be available as soon as the
        API call returns, but it is guaranteed that it will be eventually created
        if no errors are returned and Astarte is operating normally.
        You can perform the call synchronously by setting the async_operation query
        param to false.",
    operation_id: "createRealm",
    parameters: [
      async_operation: [
        in: :query,
        description: "Whether the operation should be carried out asynchronously.",
        required: false,
        schema: %Schema{type: :boolean, default: true}
      ]
    ],
    request_body: %Reference{"$ref": "#/components/requestBodies/createRealmBody"},
    responses: [
      ok:
        {"Success", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Reference{"$ref": "#/components/schemas/Realm"}
           }
         }}
    ]

  operation :show,
    summary: "Get realm configuration",
    description: "Retrieves a realm's configuration.",
    operation_id: "getRealmConfiguration",
    parameters: [
      realm_name: [
        in: :path,
        description: "Realm name",
        required: true,
        schema: %Schema{type: :string}
      ]
    ],
    responses: [
      ok:
        {"Success", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Reference{"$ref": "#/components/schemas/Realm"}
           }
         }},
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"}
    ]

  operation :update,
    summary: "Update a realm",
    description: "Updates a realm's configuration.",
    operation_id: "updateRealm",
    parameters: [
      realm_name: [
        name: :realm_name,
        in: :path,
        description: "Realm name",
        required: true,
        schema: %Schema{type: :string}
      ]
    ],
    request_body: %Reference{"$ref": "#/components/requestBodies/updateRealmBody"},
    responses: [
      ok:
        {"Success", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Reference{"$ref": "#/components/schemas/Realm"}
           }
         }},
      bad_request: "Bad request",
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      not_found:
        {"Realm not found", "application/json",
         %Reference{"$ref": "#/components/schemas/GenericError"}}
    ]

  operation :delete,
    summary: "Delete realm",
    description: "Deletes a realm from Astarte. This feature must be explicitly enabled
        in the cluster, if it's disabled a 405 status code will be returned.
        If there are connected devices present in the realm, a 422 status
        code will be returned. Realm deletion will be executed asynchronously
        by default - it is not guaranteed that the realm will be deleted as
        soon as the API call returns, but it is guaranteed that it will be
        eventually removed if no errors are returned and Astarte is
        operating normally. You can perform the call synchronously by setting
        the async_operation parameter to false.",
    operation_id: "deleteRealm",
    parameters: [
      realm_name: [
        name: :realm_name,
        in: :path,
        description: "Realm name",
        required: true,
        schema: %Schema{type: :string}
      ],
      async_operation: [
        in: :query,
        description: "Whether the operation should be carried out asynchronously.",
        required: false,
        schema: %Schema{type: :boolean, default: true}
      ]
    ],
    responses: [
      no_content: "Success",
      unauthorized: %Reference{"$ref": "#/components/responses/Unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/AuthorizationPathNotMatched"},
      method_not_allowed: "Realm deletion disabled",
      unprocessable_entity: "Connected devices present"
    ]

  def index(conn, _params) do
    with {:ok, realms} <- Realms.list_realms() do
      render(conn, "index.json", realms: realms)
    end
  end

  def create(conn, %{"data" => realm_params} = params) do
    async_operation =
      if Map.get(params, "async_operation") == "false" do
        false
      else
        true
      end

    with {:ok, %Realm{} = realm} <-
           Realms.create_realm(realm_params, async_operation: async_operation) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", realm_path(conn, :show, realm))
      |> render("show.json", realm: realm)
    end
  end

  def show(conn, %{"realm_name" => realm_name}) do
    with {:ok, %Realm{} = realm} <- Realms.get_realm(realm_name) do
      render(conn, "show.json", realm: realm)
    end
  end

  def update(%Plug.Conn{method: "PATCH"} = conn, %{
        "realm_name" => realm_name,
        "data" => realm_params
      }) do
    update_params = normalize_update_attrs(realm_params)

    with {:ok, %Realm{} = updated_realm} <- Realms.update_realm(realm_name, update_params) do
      render(conn, "show.json", realm: updated_realm)
    end
  end

  def delete(conn, %{"realm_name" => realm_name} = params) do
    async_operation =
      if Map.get(params, "async_operation") == "false" do
        false
      else
        true
      end

    with :ok <- Realms.delete_realm(realm_name, async_operation: async_operation) do
      send_resp(conn, :no_content, "")
    end
  end

  defp normalize_update_attrs(update_attrs) when is_map(update_attrs) do
    update_attrs
    |> Map.replace_lazy(:device_registration_limit, &normalize_integer_or_nil/1)
    |> Map.replace_lazy("device_registration_limit", &normalize_integer_or_nil/1)
    |> Map.replace_lazy(:datastream_maximum_storage_retention, &normalize_integer_or_nil/1)
    |> Map.replace_lazy("datastream_maximum_storage_retention", &normalize_integer_or_nil/1)
  end

  defp normalize_integer_or_nil(value) when is_nil(value), do: :unset
  defp normalize_integer_or_nil(value), do: value
end
