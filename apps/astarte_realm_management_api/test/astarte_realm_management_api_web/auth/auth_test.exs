#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.RealmManagement.APIWeb.AuthTest do
  use Astarte.RealmManagement.APIWeb.ConnCase

  alias Astarte.RealmManagement.API.JWTTestHelper
  alias Astarte.RealmManagement.Mock.DB

  @realm "testrealm"
  @request_path "/v1/#{@realm}/interfaces"
  @valid_auth_path "^interfaces$"
  @non_exact_match_valid_auth_path "^interf.*$"
  @non_matching_auth_path "^stats.*$"

  @expected_data []

  require Logger

  setup %{conn: conn} do
    DB.put_jwt_public_key_pem(@realm, JWTTestHelper.public_key_pem())
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
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

      assert json_response(conn, 200) == @expected_data
    end

    test "valid token returns the data", %{conn: conn} do
      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["^GET$::#{@valid_auth_path}"])}"
        )
        |> get(@request_path)

      assert json_response(conn, 200) == @expected_data
    end

    test "token for another path returns 403", %{conn: conn} do
      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["^GET$::#{@non_matching_auth_path}"])}"
        )
        |> get(@request_path)

      assert json_response(conn, 403)["errors"]["detail"] == "Forbidden"
    end

    test "token for both paths returns the data", %{conn: conn} do
      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{
            JWTTestHelper.gen_jwt_token([
              "^GET$::#{@non_matching_auth_path}",
              "^GET$::#{@valid_auth_path}"
            ])
          }"
        )
        |> get(@request_path)

      assert json_response(conn, 200) == @expected_data
    end

    test "token for another method returns 403", %{conn: conn} do
      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["^POST$::#{@valid_auth_path}"])}"
        )
        |> get(@request_path)

      assert json_response(conn, 403)["errors"]["detail"] == "Forbidden"
    end

    test "token for both methods returns the data", %{conn: conn} do
      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{
            JWTTestHelper.gen_jwt_token([
              "^POST$::#{@valid_auth_path}",
              "^GET$::#{@valid_auth_path}"
            ])
          }"
        )
        |> get(@request_path)

      assert json_response(conn, 200) == @expected_data
    end

    test "token with generic matching regexp returns the data", %{conn: conn} do
      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer #{JWTTestHelper.gen_jwt_token(["^.*$::#{@non_exact_match_valid_auth_path}"])}"
        )
        |> get(@request_path)

      assert json_response(conn, 200) == @expected_data
    end
  end
end
