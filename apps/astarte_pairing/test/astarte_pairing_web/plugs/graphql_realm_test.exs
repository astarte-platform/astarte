#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.PairingWeb.GraphQLRealmTest do
  use Astarte.Pairing.Cases.Conn, async: true
  use Mimic

  alias Astarte.Pairing.Queries

  @query %{query: "{ listOwnerKeys { es256 } }"}

  describe "POST /v1/graphql" do
    test "is forbidden without an astarte-realm header", %{conn: conn} do
      reject(&Queries.realm_existing?/1)

      conn = post(conn, "/v1/graphql", @query)

      assert json_response(conn, 403) == %{"errors" => %{"detail" => "Forbidden"}}
    end

    test "is forbidden for an invalid realm name, without crashing", %{conn: conn} do
      expect(Queries, :realm_existing?, fn "Bad!" -> {:ok, false} end)

      conn =
        conn
        |> put_req_header("astarte-realm", "Bad!")
        |> post("/v1/graphql", @query)

      assert json_response(conn, 403) == %{"errors" => %{"detail" => "Forbidden"}}
    end

    test "is forbidden for a realm that doesn't exist", %{conn: conn} do
      expect(Queries, :realm_existing?, fn "notarealm" -> {:ok, false} end)

      conn =
        conn
        |> put_req_header("astarte-realm", "notarealm")
        |> post("/v1/graphql", @query)

      assert json_response(conn, 403) == %{"errors" => %{"detail" => "Forbidden"}}
    end

    test "is unavailable if the realm can't be checked", %{conn: conn} do
      expect(Queries, :realm_existing?, fn "testrealm" -> {:error, :database_connection_error} end)

      conn =
        conn
        |> put_req_header("astarte-realm", "testrealm")
        |> post("/v1/graphql", @query)

      assert json_response(conn, 503)
    end
  end

  describe "POST /v1/graphiql" do
    test "treats an invalid realm name as unauthenticated, not a crash", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("astarte-realm", "Bad!")
        |> put_req_header("authorization", "Bearer not-a-jwt")
        |> post("/v1/graphiql", @query)

      assert %{"errors" => [%{"message" => "Unauthorized: Missing valid user session"}]} =
               json_response(conn, 200)
    end
  end
end
