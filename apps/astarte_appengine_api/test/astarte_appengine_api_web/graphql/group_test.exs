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
defmodule Astarte.AppEngine.APIWeb.GraphQL.GroupTest do
  use Astarte.AppEngine.API.Cases.Data, async: true
  use Astarte.AppEngine.API.Cases.Conn
  use Astarte.Auth.Cases.AuthorizationModel

  alias Astarte.AppEngine.API.Groups
  alias Astarte.AppEngine.API.Helpers.JWT
  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.DataAccess.Device
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  @name_query "query ($name: String!) { group(name: $name) { name } }"

  @forbidden "Forbidden: OpenFGA denied access for this action"

  setup_all %{realm_name: realm_name, store_id: store_id} do
    JWT.install_public_key!(realm_name)

    keyspace = Realm.keyspace_name(realm_name)

    [device_id, other_device_id] =
      for _ <- 1..2 do
        device_id = CoreDevice.random_device_id()
        Repo.insert!(%Device{device_id: device_id}, prefix: keyspace)
        CoreDevice.encode_device_id(device_id)
      end

    {:ok, _group} =
      Groups.create_group(realm_name, %{"group_name" => "line4", "devices" => [device_id]})

    {:ok, _group} =
      Groups.create_group(realm_name, %{"group_name" => "line5", "devices" => [other_device_id]})

    write_tuples!(store_id, [
      %{user: "user:#{realm_name}/grantee", relation: "observer", object: "realm:#{realm_name}"},
      %{
        user: "user:#{realm_name}/group_grantee",
        relation: "observer",
        object: "device_group:#{realm_name}/line4"
      },
      %{
        user: "user:#{realm_name}/device_grantee",
        relation: "observer",
        object: "device:#{realm_name}/#{device_id}"
      }
    ])

    %{device_id: device_id, other_device_id: other_device_id}
  end

  setup %{conn: conn, realm_name: realm_name} do
    {:ok, conn: put_req_header(conn, "astarte-realm", realm_name)}
  end

  test "a realm role in the token grants the group query", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    assert %{"data" => %{"group" => %{"name" => "line4"}}} =
             query(conn, token, @name_query, %{name: "line4"})
  end

  test "a realm role stored in OpenFGA grants the group query", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles([], "grantee")

    assert %{"data" => %{"group" => %{"name" => "line4"}}} =
             query(conn, token, @name_query, %{name: "line4"})
  end

  test "a role on the group grants the group query", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles([], "group_grantee")

    assert %{"data" => %{"group" => %{"name" => "line4"}}} =
             query(conn, token, @name_query, %{name: "line4"})
  end

  test "a role on another group doesn't grant the group query", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles([], "group_grantee")

    conn |> query(token, @name_query, %{name: "line5"}) |> assert_error(@forbidden)
  end

  test "a role on a device of the group doesn't grant the group query", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles([], "device_grantee")

    conn |> query(token, @name_query, %{name: "line4"}) |> assert_error(@forbidden)
  end

  test "a group that doesn't exist is not found", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    conn |> query(token, @name_query, %{name: "line6"}) |> assert_error("group_not_found")
  end

  test "a group that doesn't exist is forbidden without a role on it", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles([], "group_grantee")

    conn |> query(token, @name_query, %{name: "line6"}) |> assert_error(@forbidden)
  end

  test "a name that can't be an OpenFGA object is rejected", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    conn |> query(token, @name_query, %{name: "line 4"}) |> assert_error("Invalid argument: name")
  end

  defp query(conn, token, query, variables) do
    conn
    |> put_req_header("authorization", "bearer #{token}")
    |> put_req_header("content-type", "application/json")
    |> post("/v1/graphql", Jason.encode!(%{query: query, variables: variables}))
    |> json_response(200)
  end

  defp assert_error(response, message) do
    assert %{"data" => %{"group" => nil}, "errors" => [%{"message" => ^message}]} = response
  end
end
