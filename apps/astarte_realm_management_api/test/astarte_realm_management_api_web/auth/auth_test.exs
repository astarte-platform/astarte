#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.APIWeb.AuthTest do
  use Astarte.RealmManagement.APIWeb.ConnCase

  alias Astarte.Helpers
  alias Astarte.RealmManagement.API.Helpers.JWTTestHelper

  @valid_auth_path "^interfaces$"
  @valid_auth_path_no_delim "interfaces"
  @non_exact_match_valid_auth_path "^interf.*$"
  @non_matching_auth_path "^stats.*$"

  @expected_data []

  require Logger

  setup %{conn: conn, realm_name: realm_name, jwt_public_key: key} do
    Helpers.Database.insert_public_key!(realm_name, key)
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "JWT" do
    test "no token returns 401", %{conn: conn, realm_name: realm_name} do
      request_path = "/v1/#{realm_name}/interfaces"
      conn = get(conn, request_path)
      assert json_response(conn, 401)["errors"]["detail"] == "Unauthorized"
    end

    test "all access token returns the data", %{conn: conn, realm_name: realm_name} do
      request_path = "/v1/#{realm_name}/interfaces"

      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_all_access_token()}"
        )
        |> get(request_path)

      assert json_response(conn, 200)["data"] == @expected_data
    end

    test "valid token returns the data", %{conn: conn, realm_name: realm_name} do
      request_path = "/v1/#{realm_name}/interfaces"

      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["^GET$::#{@valid_auth_path}"])}"
        )
        |> get(request_path)

      assert json_response(conn, 200)["data"] == @expected_data
    end

    test "valid token without delimiters returns the data", %{conn: conn, realm_name: realm_name} do
      request_path = "/v1/#{realm_name}/interfaces"

      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["GET::#{@valid_auth_path_no_delim}"])}"
        )
        |> get(request_path)

      assert json_response(conn, 200)["data"] == @expected_data
    end

    test "valid token for prefix returns 403", %{conn: conn, realm_name: realm_name} do
      request_path = "/v1/#{realm_name}/interfaces"

      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["GET::#{@valid_auth_path_no_delim}"])}"
        )
        |> get("#{request_path}/suffix")

      assert json_response(conn, 403)["errors"]["detail"] == "Forbidden"
    end

    test "token for another path returns 403", %{conn: conn, realm_name: realm_name} do
      request_path = "/v1/#{realm_name}/interfaces"

      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["^GET$::#{@non_matching_auth_path}"])}"
        )
        |> get(request_path)

      assert json_response(conn, 403)["errors"]["detail"] == "Forbidden"
    end

    test "token for both paths returns the data", %{
      conn: conn,
      realm_name: realm_name
    } do
      request_path = "/v1/#{realm_name}/interfaces"

      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["^GET$::#{@non_matching_auth_path}", "^GET$::#{@valid_auth_path}"])}"
        )
        |> get(request_path)

      assert json_response(conn, 200)["data"] == @expected_data
    end

    test "token for another method returns 403", %{conn: conn, realm_name: realm_name} do
      request_path = "/v1/#{realm_name}/interfaces"

      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["^POST$::#{@valid_auth_path}"])}"
        )
        |> get(request_path)

      assert json_response(conn, 403)["errors"]["detail"] == "Forbidden"
    end

    test "token for both methods returns the data", %{conn: conn, realm_name: realm_name} do
      request_path = "/v1/#{realm_name}/interfaces"

      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["^POST$::#{@valid_auth_path}", "^GET$::#{@valid_auth_path}"])}"
        )
        |> get(request_path)

      assert json_response(conn, 200)["data"] == @expected_data
    end

    test "token with generic matching regexp returns the data", %{
      conn: conn,
      realm_name: realm_name
    } do
      request_path = "/v1/#{realm_name}/interfaces"

      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["^.*$::#{@non_exact_match_valid_auth_path}"])}"
        )
        |> get(request_path)

      assert json_response(conn, 200)["data"] == @expected_data
    end
  end
end
