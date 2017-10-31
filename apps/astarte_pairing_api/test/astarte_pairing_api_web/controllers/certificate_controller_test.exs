defmodule Astarte.Pairing.APIWeb.CertificateControllerTest do
  use Astarte.Pairing.APIWeb.ConnCase

  alias Astarte.Pairing.Mock

  describe "create certificate" do
    @csr "testcsr"
    @create_attrs %{"data" => @csr}
    @invalid_attrs %{"data" => ""}

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

  describe "verify certificate" do
    @valid_crt Mock.valid_crt()

    @verify_attrs %{"data" => @valid_crt}
    @invalid_crt_attrs %{"data" => "invalid"}
    @invalid_attrs %{"data" => ""}

    setup %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-api-key", Mock.valid_api_key())
      {:ok, conn: conn}
    end

    test "renders certificate status when data is valid", %{conn: conn} do
      conn = post conn, certificate_path(conn, :verify), @verify_attrs
      assert %{"valid" => true,
               "timestamp" => _timestamp,
               "until" => _until} = json_response(conn, 201)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, certificate_path(conn, :verify), @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders certificate status when certificate is invalid", %{conn: conn} do
      conn = post conn, certificate_path(conn, :verify), @invalid_crt_attrs
      assert %{"valid" => false,
               "timestamp" => _timestamp,
               "cause" => _cause,
               "details" => _details} = json_response(conn, 201)
    end
  end
end
