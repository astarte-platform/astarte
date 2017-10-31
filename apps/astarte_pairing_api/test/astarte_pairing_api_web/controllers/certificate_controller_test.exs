defmodule Astarte.Pairing.APIWeb.CertificateControllerTest do
  use Astarte.Pairing.APIWeb.ConnCase

  alias Astarte.Pairing.Mock

  @csr "testcsr"
  @create_attrs %{"data" => @csr}
  @invalid_attrs %{"data" => ""}

  describe "create api_key" do
    setup %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-api-key", Mock.valid_api_key())
        |> put_resp_header("accept", "application/json")
      {:ok, conn: conn}
    end


    test "renders certificate when data is valid", %{conn: conn} do
      conn = post conn, certificate_path(conn, :create), @create_attrs
      assert %{"clientCrt" => clientCrt} = json_response(conn, 201)
      assert clientCrt == Mock.certificate(@csr, "127.0.0.1")
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, certificate_path(conn, :create), @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders errors when no authorization header", %{conn: conn} do
      conn =
        conn
        |> delete_req_header("x-api-key")
        |> post(certificate_path(conn, :create), @create_attrs)

      assert json_response(conn, 401)["errors"] == %{"detail" => "Unauthorized"}
    end

    test "renders errors when unauthorized", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-api-key", "invalidapikey")
        |> post(certificate_path(conn, :create), @create_attrs)

      assert json_response(conn, 401)["errors"] == %{"detail" => "Unauthorized"}
    end
  end
end
