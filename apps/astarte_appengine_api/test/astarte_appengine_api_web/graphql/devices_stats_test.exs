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

defmodule Astarte.AppEngine.APIWeb.GraphQL.DevicesStatsTest do
  use Astarte.AppEngine.API.Cases.Data, async: true
  use Astarte.AppEngine.API.Cases.Conn
  use Astarte.Auth.Cases.AuthorizationModel
  use Mimic

  alias Astarte.AppEngine.API.Auth
  alias Astarte.AppEngine.API.Helpers.JWT
  alias Astarte.Auth.OpenFGA
  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.DataAccess.Device
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  @query "{ devicesStats { totalDevices connectedDevices } }"
  @stats %{"totalDevices" => 1, "connectedDevices" => 0}
  @forbidden "Forbidden: OpenFGA denied access for this action"
  @unauthorized "Unauthorized: Missing valid user session"

  setup_all %{realm_name: realm_name, store_id: store_id} do
    JWT.install_public_key!(realm_name)

    Repo.insert!(%Device{device_id: CoreDevice.random_device_id()},
      prefix: Realm.keyspace_name(realm_name)
    )

    write_tuples!(store_id, [
      %{user: "user:#{realm_name}/grantee", relation: "observer", object: "realm:#{realm_name}"},
      %{user: "user:otherrealm/testuser", relation: "observer", object: "realm:#{realm_name}"}
    ])
  end

  setup %{conn: conn, realm_name: realm_name} do
    {:ok, conn: put_req_header(conn, "astarte-realm", realm_name)}
  end

  describe "with a valid identity" do
    test "a role in the token grants its capabilities", %{conn: conn} do
      token = JWT.gen_jwt_token_with_roles(["observer"])

      assert %{"data" => %{"devicesStats" => @stats}} ==
               conn |> authenticated(token) |> query()
    end

    test "a role stored in OpenFGA grants its capabilities", %{conn: conn} do
      token = JWT.gen_jwt_token_with_roles([], "grantee")

      assert %{"data" => %{"devicesStats" => @stats}} ==
               conn |> authenticated(token) |> query()
    end

    test "a role without the capability is denied", %{conn: conn} do
      token = JWT.gen_jwt_token_with_roles(["trigger_manager"])

      conn |> authenticated(token) |> query() |> assert_error(@forbidden)
    end

    test "a role the model doesn't define is ignored", %{conn: conn} do
      token = JWT.gen_jwt_token_with_roles(["superuser"])

      conn |> authenticated(token) |> query() |> assert_error(@forbidden)
    end

    test "a grant to the same subject of another realm doesn't count", %{conn: conn} do
      token = JWT.gen_jwt_token_with_roles([])

      conn |> authenticated(token) |> query() |> assert_error(@forbidden)
    end

    # an unreachable OpenFGA can't be set up for real without affecting the other tests
    test "fails closed when OpenFGA can't answer", %{conn: conn} do
      expect(OpenFGA, :check, fn _user, _relation, _object, _tuples -> {:error, :timeout} end)
      token = JWT.gen_jwt_token_with_roles(["observer"])

      conn
      |> authenticated(token)
      |> query()
      |> assert_error("Internal Server Error during authorization")
    end
  end

  describe "without a valid identity" do
    test "no token is unauthorized", %{conn: conn} do
      conn |> query() |> assert_error(@unauthorized)
    end

    test "a token not signed by the realm is unauthorized", %{conn: conn} do
      token = JWT.gen_jwt_token_with_wrong_signature([])

      conn |> authenticated(token) |> query() |> assert_error(@unauthorized)
    end

    test "no realm ends the request with a GraphQL error", %{conn: conn} do
      token = JWT.gen_jwt_token_with_roles(["observer"])

      assert %{"errors" => [%{"message" => "Missing the astarte-realm header"}]} ==
               conn
               |> delete_req_header("astarte-realm")
               |> authenticated(token)
               |> query()
    end

    test "an invalid realm name ends the request with a GraphQL error", %{conn: conn} do
      token = JWT.gen_jwt_token_with_roles(["observer"])

      assert %{"errors" => [%{"message" => "Invalid realm name in the astarte-realm header"}]} ==
               conn
               |> put_req_header("astarte-realm", "Not;A;Realm")
               |> authenticated(token)
               |> query()
    end

    test "a realm that doesn't exist is unauthorized", %{conn: conn} do
      token = JWT.gen_jwt_token_with_roles(["observer"])

      conn
      |> put_req_header("astarte-realm", "nosuchrealm")
      |> authenticated(token)
      |> query()
      |> assert_error(@unauthorized)
    end
  end

  # a database failure can't be set up for real without affecting the other tests
  test "a database failure on the realm's key is a server error",
       %{conn: conn, realm_name: realm_name} do
    expect(Auth, :fetch_public_key, fn ^realm_name -> {:error, :database_connection_error} end)
    token = JWT.gen_jwt_token_with_roles(["observer"])

    assert_error_sent 500, fn -> conn |> authenticated(token) |> query() end
  end

  defp authenticated(conn, token) do
    put_req_header(conn, "authorization", "bearer #{token}")
  end

  defp query(conn) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post("/v1/graphql", Jason.encode!(%{query: @query}))
    |> json_response(200)
  end

  defp assert_error(response, message) do
    assert %{"data" => %{"devicesStats" => nil}, "errors" => [%{"message" => ^message}]} =
             response
  end
end
