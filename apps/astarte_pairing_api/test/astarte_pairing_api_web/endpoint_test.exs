defmodule Astarte.Pairing.APIWeb.EndpointTest do
  use Astarte.Pairing.APIWeb.ConnCase

  alias Astarte.Pairing.Mock

  @invalid_attrs ""

  describe "create certificate" do
    @create_attrs "csr"

    setup %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-api-key", Mock.valid_api_key())
        |> put_resp_header("accept", "application/json")
      {:ok, conn: conn}
    end

    test "renders certificate when data is valid", %{conn: conn} do
      conn = post conn, "/api/v1/pairing", @create_attrs
      assert %{"clientCrt" => clientCrt} = json_response(conn, 201)
      assert clientCrt == Mock.certificate(@create_attrs, "127.0.0.1")
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, "/api/v1/pairing", @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end
end
