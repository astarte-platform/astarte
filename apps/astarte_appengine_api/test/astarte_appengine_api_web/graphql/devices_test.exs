#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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
defmodule Astarte.AppEngine.APIWeb.GraphQL.DevicesTest do
  use Astarte.AppEngine.API.Cases.Data, async: true
  use Astarte.AppEngine.API.Cases.Conn
  use Astarte.Auth.Cases.AuthorizationModel

  alias Astarte.AppEngine.API.Helpers.JWT
  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.DataAccess.Device
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  @query """
  query ($limit: Int, $fromToken: PageToken) {
    devices(limit: $limit, fromToken: $fromToken) { devices { id } nextToken }
  }
  """

  @forbidden "Forbidden: OpenFGA denied access for this action"

  setup_all %{realm_name: realm_name} do
    JWT.install_public_key!(realm_name)

    device_ids =
      for _ <- 1..3 do
        device_id = CoreDevice.random_device_id()
        Repo.insert!(%Device{device_id: device_id}, prefix: Realm.keyspace_name(realm_name))
        CoreDevice.encode_device_id(device_id)
      end

    %{device_ids: Enum.sort(device_ids)}
  end

  setup %{conn: conn, realm_name: realm_name} do
    {:ok, conn: put_req_header(conn, "astarte-realm", realm_name)}
  end

  test "a realm role in the token lists the devices", %{conn: conn, device_ids: device_ids} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    assert %{"data" => %{"devices" => %{"devices" => devices, "nextToken" => nil}}} =
             query(conn, token, %{})

    assert ids(devices) == device_ids
  end

  test "a fleet_manager lists the devices", %{conn: conn, device_ids: device_ids} do
    token = JWT.gen_jwt_token_with_roles(["fleet_manager"])

    assert %{"data" => %{"devices" => %{"devices" => devices}}} = query(conn, token, %{})
    assert ids(devices) == device_ids
  end

  test "a role without the capability is denied", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["trigger_manager"])

    assert %{"data" => %{"devices" => nil}, "errors" => [%{"message" => @forbidden}]} =
             query(conn, token, %{})
  end

  test "nextToken leads to the next page", %{conn: conn, device_ids: device_ids} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    assert %{"data" => %{"devices" => %{"devices" => first_page, "nextToken" => next_token}}} =
             query(conn, token, %{limit: 2})

    assert %{"data" => %{"devices" => %{"devices" => last_page, "nextToken" => nil}}} =
             query(conn, token, %{limit: 2, fromToken: next_token})

    assert length(first_page) == 2
    assert ids(first_page ++ last_page) == device_ids
  end

  test "a null fromToken returns the first page", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    assert %{"data" => %{"devices" => %{"devices" => [_, _], "nextToken" => next_token}}} =
             first_page = query(conn, token, %{limit: 2})

    assert is_binary(next_token)
    assert query(conn, token, %{limit: 2, fromToken: nil}) == first_page
  end

  test "a limit that isn't positive is a validation error", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    assert %{
             "data" => %{"devices" => nil},
             "errors" => [
               %{
                 "message" => "Validation failed",
                 "details" => %{"limit" => ["must be greater than 0"]}
               }
             ]
           } = query(conn, token, %{limit: 0})
  end

  test "a null limit is a validation error", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    assert %{"errors" => [%{"message" => "Argument \"limit\" has invalid value $limit."}]} =
             query(conn, token, %{limit: nil})
  end

  test "a fromToken that isn't an integer is rejected", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    assert %{"errors" => [%{"message" => "Argument \"fromToken\" has invalid value $fromToken."}]} =
             query(conn, token, %{fromToken: "next"})
  end

  test "a fromToken that isn't a string is rejected", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    assert %{"errors" => [%{"message" => "Argument \"fromToken\" has invalid value $fromToken."}]} =
             query(conn, token, %{fromToken: 5})
  end

  defp query(conn, token, variables) do
    conn
    |> put_req_header("authorization", "bearer #{token}")
    |> put_req_header("content-type", "application/json")
    |> post("/v1/graphql", Jason.encode!(%{query: @query, variables: variables}))
    |> json_response(200)
  end

  defp ids(devices), do: devices |> Enum.map(& &1["id"]) |> Enum.sort()
end
