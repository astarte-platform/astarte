defmodule Astarte.AppEngine.APIWeb.AuthTest do
  use Astarte.AppEngine.APIWeb.ConnCase

  alias Astarte.AppEngine.API.JWTTestHelper

  @realm "autotestrealm"
  @device_id "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ"
  @interface "com.test.LCDMonitor"
  @escaped_interface "com\\.test\\.LCDMonitor"
  @path "/time/to"
  @request_path "/v1/#{@realm}/devices/#{@device_id}/interfaces/#{@interface}#{@path}"
  @valid_auth_path "devices/#{@device_id}/interfaces/#{@escaped_interface}#{@path}"
  @other_device_id "OTHERDEVICEAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ"
  @other_device_auth_path "devices/#{@other_device_id}/interfaces/#{@escaped_interface}#{@path}"

  @expected_data 20

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  setup_all do
    {:ok, _client} = Astarte.RealmManagement.DatabaseTestHelper.create_test_keyspace()

    on_exit(fn ->
      Astarte.RealmManagement.DatabaseTestHelper.destroy_local_test_keyspace()
    end)

    :ok
  end

  describe "JWT" do
    test "no token returns 401", %{conn: conn} do
      conn = get(conn, @request_path)
      assert json_response(conn, 401)["errors"]["detail"] == "Unauthorized"
    end

    test "all access token returns the data", %{conn: conn} do
      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_all_access_token()}"
        )
        |> get(@request_path)

      assert json_response(conn, 200)["data"] == @expected_data
    end

    test "token returns the data", %{conn: conn} do
      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["GET::#{@valid_auth_path}"])}"
        )
        |> get(@request_path)

      assert json_response(conn, 200)["data"] == @expected_data
    end

    test "token for another device returns 403", %{conn: conn} do
      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["GET::#{@other_device_auth_path}"])}"
        )
        |> get(@request_path)

      assert json_response(conn, 403)["errors"]["detail"] == "Forbidden"
    end

    test "token for both devices returns the data", %{conn: conn} do
      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{
            JWTTestHelper.gen_jwt_token([
              "GET::#{@other_device_auth_path}",
              "GET::#{@valid_auth_path}"
            ])
          }"
        )
        |> get(@request_path)

      assert json_response(conn, 200)["data"] == @expected_data
    end

    test "token for another method returns 403", %{conn: conn} do
      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["POST::#{@valid_auth_path}"])}"
        )
        |> get(@request_path)

      assert json_response(conn, 403)["errors"]["detail"] == "Forbidden"
    end

    test "token with generic matching regexp returns the data", %{conn: conn} do
      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["GET::devices/#{@device_id}/.*"])}"
        )
        |> get(@request_path)

      assert json_response(conn, 200)["data"] == @expected_data
    end
  end
end
