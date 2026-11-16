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
defmodule Astarte.AppEngine.APIWeb.GraphQL.GroupsTest do
  use Astarte.AppEngine.API.Cases.Data, async: true
  use Astarte.AppEngine.API.Cases.Conn
  use Astarte.Auth.Cases.AuthorizationModel

  alias Astarte.AppEngine.API.Groups
  alias Astarte.AppEngine.API.Helpers.JWT
  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.DataAccess.Device
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  @query "{ groups }"

  @forbidden "Forbidden: OpenFGA denied access for this action"

  setup_all %{realm_name: realm_name, store_id: store_id} do
    JWT.install_public_key!(realm_name)

    device_id = CoreDevice.random_device_id()
    Repo.insert!(%Device{device_id: device_id}, prefix: Realm.keyspace_name(realm_name))
    device_id = CoreDevice.encode_device_id(device_id)

    for group_name <- ["line4", "line5"] do
      {:ok, _group} =
        Groups.create_group(realm_name, %{"group_name" => group_name, "devices" => [device_id]})
    end

    write_tuples!(store_id, [
      %{user: "user:#{realm_name}/grantee", relation: "observer", object: "realm:#{realm_name}"},
      %{
        user: "user:#{realm_name}/group_grantee",
        relation: "observer",
        object: "device_group:#{realm_name}/line4"
      }
    ])

    :ok
  end

  setup %{conn: conn, realm_name: realm_name} do
    {:ok, conn: put_req_header(conn, "astarte-realm", realm_name)}
  end

  test "a realm role in the token lists the groups", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["observer"])

    assert %{"data" => %{"groups" => groups}} = query(conn, token)
    assert Enum.sort(groups) == ["line4", "line5"]
  end

  test "a realm role stored in OpenFGA lists the groups", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles([], "grantee")

    assert %{"data" => %{"groups" => groups}} = query(conn, token)
    assert Enum.sort(groups) == ["line4", "line5"]
  end

  test "a fleet_manager lists the groups", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["fleet_manager"])

    assert %{"data" => %{"groups" => [_, _]}} = query(conn, token)
  end

  test "a role without the capability is denied", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles(["trigger_manager"])

    assert %{"data" => %{"groups" => nil}, "errors" => [%{"message" => @forbidden}]} =
             query(conn, token)
  end

  test "a role on a group doesn't list the groups", %{conn: conn} do
    token = JWT.gen_jwt_token_with_roles([], "group_grantee")

    assert %{"data" => %{"groups" => nil}, "errors" => [%{"message" => @forbidden}]} =
             query(conn, token)
  end

  defp query(conn, token) do
    conn
    |> put_req_header("authorization", "bearer #{token}")
    |> put_req_header("content-type", "application/json")
    |> post("/v1/graphql", Jason.encode!(%{query: @query}))
    |> json_response(200)
  end
end
