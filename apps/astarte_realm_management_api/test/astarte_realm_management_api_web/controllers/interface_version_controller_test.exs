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

defmodule Astarte.RealmManagement.APIWeb.InterfaceVersionControllerTest do
  use Astarte.RealmManagement.APIWeb.ConnCase

  alias Astarte.RealmManagement.API.Helpers.JWTTestHelper
  alias Astarte.RealmManagement.API.Helpers.RPCMock.DB

  @realm "testrealm"
  @interface_name "com.Some.Interface"
  @interface_major 2
  @valid_attrs %{
    "interface_name" => @interface_name,
    "version_major" => 2,
    "version_minor" => 1,
    "type" => "properties",
    "ownership" => "device",
    "mappings" => [
      %{
        "endpoint" => "/test",
        "type" => "integer"
      }
    ]
  }

  setup %{conn: conn} do
    DB.put_jwt_public_key_pem(@realm, JWTTestHelper.public_key_pem())
    token = JWTTestHelper.gen_jwt_all_access_token()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn}
  end

  describe "index" do
    test "lists empty interface versions", %{conn: conn} do
      conn = get(conn, interface_version_path(conn, :index, @realm, @interface_name))
      assert json_response(conn, 200)["data"] == []
    end

    test "lists interface after installing it", %{conn: conn} do
      post_conn = post(conn, interface_path(conn, :create, @realm), data: @valid_attrs)
      assert response(post_conn, 201) == ""

      list_conn = get(conn, interface_version_path(conn, :index, @realm, @interface_name))
      assert json_response(list_conn, 200)["data"] == [@interface_major]
    end

    test "lists multiple major versions", %{conn: conn} do
      post_conn_1 = post(conn, interface_path(conn, :create, @realm), data: @valid_attrs)
      assert response(post_conn_1, 201) == ""

      next_major_attrs = %{@valid_attrs | "version_major" => @interface_major + 1}
      post_conn_2 = post(conn, interface_path(conn, :create, @realm), data: next_major_attrs)
      assert response(post_conn_2, 201) == ""

      list_conn = get(conn, interface_version_path(conn, :index, @realm, @interface_name))
      assert json_response(list_conn, 200)["data"] == [@interface_major, @interface_major + 1]
    end
  end
end
