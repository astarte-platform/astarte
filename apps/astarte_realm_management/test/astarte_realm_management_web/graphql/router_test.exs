defmodule Astarte.RealmManagementWeb.GraphQL.RouterTest do
  use Astarte.RealmManagement.Cases.Data, async: true
  use Astarte.RealmManagementWeb.ConnCase

  describe "POST /v1/graphql" do
    test "accesses the graphql endpoint", %{auth_conn: conn, realm: realm} do
      query = """
      query {
        health
      }
      """

      conn =
        conn
        |> put_req_header("astarte-realm", realm)
        |> post("/v1/graphql", %{"query" => query})

      assert json_response(conn, 200) == %{
               "data" => %{"health" => "Realm Management GraphQL API is running"}
             }
    end
  end
end
