defmodule Astarte.Pairing.APIWeb.APIKeyControllerTest do
  use Astarte.Pairing.APIWeb.ConnCase

  alias Astarte.Pairing.API.Agent.Realm
  alias Astarte.Pairing.APIWeb.TestJWTProducer
  alias Astarte.Pairing.Mock

  @test_realm "testrealm"
  @test_hw_id "testhwid"
  @invalid_hw_id ""

  @create_attrs %{"hwId" => @test_hw_id}
  @invalid_attrs %{"hwId" => @invalid_hw_id}
  @existing_attrs %{"hwId" => Mock.existing_hw_id()}

  describe "create api_key" do
    setup %{conn: conn} do
      {:ok, jwt, _claims} =
        %Realm{realm_name: @test_realm}
        |> TestJWTProducer.encode_and_sign()

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", jwt)
      {:ok, conn: conn}
    end


    test "renders api_key when data is valid", %{conn: conn} do
      conn = post conn, api_key_path(conn, :create), @create_attrs
      assert %{"apiKey" => api_key} = json_response(conn, 201)
      assert api_key == Mock.api_key(@test_realm, @test_hw_id)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, api_key_path(conn, :create), @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders errors when device already exists", %{conn: conn} do
      conn = post conn, api_key_path(conn, :create), @existing_attrs
      assert json_response(conn, 422)["errors"] == %{"error_name" => ["device_exists"]}
    end

    test "renders errors when unauthorized", %{conn: conn} do
      conn =
        conn
        |> delete_req_header("authorization")
        |> post(api_key_path(conn, :create), api_key: @create_attrs)

      assert json_response(conn, 401)["errors"] == %{"detail" => "Unauthorized"}
    end
  end
end
