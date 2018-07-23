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

defmodule Astarte.RealmManagement.APIWeb.InterfaceVersionControllerTest do
  use Astarte.RealmManagement.APIWeb.ConnCase

  alias Astarte.RealmManagement.API.JWTTestHelper
  alias Astarte.RealmManagement.Mock

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
    Mock.DB.put_jwt_public_key_pem(@realm, JWTTestHelper.public_key_pem())
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
