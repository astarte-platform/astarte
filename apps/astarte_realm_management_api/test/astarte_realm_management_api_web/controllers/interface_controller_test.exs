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

defmodule Astarte.RealmManagement.APIWeb.InterfaceControllerTest do
  use Astarte.RealmManagement.APIWeb.ConnCase

  alias Astarte.RealmManagement.API.Triggers
  alias Astarte.RealmManagement.API.Triggers.Trigger
  alias Astarte.RealmManagement.API.JWTTestHelper
  alias Astarte.RealmManagement.Mock

  @realm "testrealm"
  @interface_name "com.Some.Interface"
  @interface_major 2
  @interface_major_str Integer.to_string(@interface_major)
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
  @invalid_attrs %{
    "interface_name" => @interface_name,
    "version_major" => 2,
    "version_minor" => 1,
    "type" => "INVALID",
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
    test "lists empty interfaces", %{conn: conn} do
      conn = get(conn, interface_path(conn, :index, @realm))
      assert json_response(conn, 200)["data"] == []
    end

    test "lists interface after installing it", %{conn: conn} do
      post_conn = post(conn, interface_path(conn, :create, @realm), data: @valid_attrs)
      assert response(post_conn, 201) == ""

      list_conn = get(conn, interface_path(conn, :index, @realm))
      assert json_response(list_conn, 200)["data"] == [@interface_name]
    end
  end

  describe "show" do
    test "shows existing interface", %{conn: conn} do
      post_conn = post(conn, interface_path(conn, :create, @realm), data: @valid_attrs)
      assert response(post_conn, 201) == ""

      show_conn = get(conn, interface_path(conn, :show, @realm, @interface_name, @interface_major_str))
      assert json_response(show_conn, 200)["data"]["interface_name"] == @interface_name
    end

    test "renders error on non-existing interface", %{conn: conn} do
      conn = get(conn, interface_path(conn, :show, @realm, "com.Nonexisting", @interface_major_str))
      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  describe "create interface" do
    test "renders interface when data is valid", %{conn: conn} do
      post_conn = post(conn, interface_path(conn, :create, @realm), data: @valid_attrs)
      assert response(post_conn, 201) == ""

      get_conn = get(conn, interface_path(conn, :show, @realm, @interface_name, @interface_major_str))
      assert json_response(get_conn, 200)["data"] == @valid_attrs
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, interface_path(conn, :create, @realm), data: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders error when interface is already installed", %{conn: conn} do
      post_conn = post(conn, interface_path(conn, :create, @realm), data: @valid_attrs)
      assert response(post_conn, 201) == ""

      post2_conn = post(conn, interface_path(conn, :create, @realm), data: @valid_attrs)
      assert json_response(post2_conn, 409)["errors"] != %{}
    end
  end

  describe "update" do
    test "updates interface when data is valid", %{conn: conn} do
      create_conn = post(conn, interface_path(conn, :create, @realm), data: @valid_attrs)
      assert response(create_conn, 201) == ""

      new_mapping = %{"endpoint" => "/other", "type" => "string"}
      updated_mappings = [new_mapping | @valid_attrs["mappings"]]
      new_minor = @valid_attrs["version_minor"] + 1
      update_attrs = %{@valid_attrs | "version_minor" => new_minor, "mappings" => updated_mappings}
      update_conn = put(conn, interface_path(conn, :update, @realm, @interface_name, @interface_major_str), data: update_attrs)

      get_conn = get(conn, interface_path(conn, :show, @realm, @interface_name, @interface_major_str))
      assert json_response(get_conn, 200)["data"] == update_attrs
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = put(conn, interface_path(conn, :update, @realm, @interface_name, @interface_major_str), data: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders error when major is not a number", %{conn: conn} do
      conn = put(conn, interface_path(conn, :update, @realm, @interface_name, "notanumber"), data: @valid_attrs)
      assert json_response(conn, 404)["errors"] != %{}
    end

    test "renders error when name doesn't match", %{conn: conn} do
      conn = put(conn, interface_path(conn, :update, @realm, "com.Other.Interface", @interface_major_str), data: @valid_attrs)
      assert json_response(conn, 409)["errors"] != %{}
    end

    test "renders error when major doesn't match", %{conn: conn} do
      conn = put(conn, interface_path(conn, :update, @realm, @interface_name, "42"), data: @valid_attrs)
      assert json_response(conn, 409)["errors"] != %{}
    end

    test "renders error when interface doesn't exist", %{conn: conn} do
      other_interface = "com.Other"
      attrs = %{@valid_attrs | "interface_name" => other_interface}

      conn =
        put(
          conn,
          interface_path(conn, :update, @realm, other_interface, @interface_major_str),
          data: attrs
        )

      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  describe "delete" do
    test "deletes existing interface", %{conn: conn} do
      post_conn = post(conn, interface_path(conn, :create, @realm), data: @valid_attrs)
      assert response(post_conn, 201) == ""

      delete_conn = get(conn, interface_path(conn, :delete, @realm, @interface_name, @interface_major_str))
      assert response(delete_conn, 200)
    end

    test "renders error on non-existing interface", %{conn: conn} do
      delete_conn = get(conn, interface_path(conn, :delete, @realm, "com.Nonexisting", @interface_major_str))
      assert json_response(delete_conn, 404)["errors"] != %{}
    end
  end
end
