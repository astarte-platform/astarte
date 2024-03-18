#
# This file is part of Astarte.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Astarte.RealmManagement.APIWeb.TriggerPolicyControllerTest do
  use Astarte.RealmManagement.APIWeb.ConnCase

  alias Astarte.RealmManagement.API.JWTTestHelper
  alias Astarte.RealmManagement.Mock

  @realm "testrealm"
  @policy_name "somepolicy"
  @valid_attrs %{
    "name" => @policy_name,
    "maximum_capacity" => 100,
    "error_handlers" => [
      %{"on" => "any_error", "strategy" => "discard"}
    ]
  }

  @invalid_attrs %{
    "name" => "@invalid",
    "maximum_capacity" => 100,
    "error_handlers" => [
      %{"on" => "any_error", "strategy" => "discard"}
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
    test "lists empty policies", %{conn: conn} do
      conn = get(conn, trigger_policy_path(conn, :index, @realm))
      assert json_response(conn, 200)["data"] == []
    end

    test "lists policy after installing it", %{conn: conn} do
      post_conn = post(conn, trigger_policy_path(conn, :create, @realm), data: @valid_attrs)
      assert response(post_conn, 201) == ""

      list_conn = get(conn, trigger_policy_path(conn, :index, @realm))
      assert json_response(list_conn, 200)["data"] == [@policy_name]
    end
  end

  describe "show" do
    test "shows existing policy", %{conn: conn} do
      post_conn = post(conn, trigger_policy_path(conn, :create, @realm), data: @valid_attrs)
      assert response(post_conn, 201) == ""

      show_conn = get(conn, trigger_policy_path(conn, :show, @realm, @policy_name))

      assert json_response(show_conn, 200)["data"]["policy_name"] == @policy_name
    end

    test "renders error on non-existing policy", %{conn: conn} do
      conn = get(conn, trigger_policy_path(conn, :show, @realm, "nonexisting"))

      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  describe "create policy" do
    test "renders policy when data is valid", %{conn: conn} do
      post_conn = post(conn, trigger_policy_path(conn, :create, @realm), data: @valid_attrs)
      assert response(post_conn, 201) == ""

      get_conn = get(conn, trigger_policy_path(conn, :show, @realm, @policy_name))

      assert json_response(get_conn, 200)["data"] == @valid_attrs
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, trigger_policy_path(conn, :create, @realm), data: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders error when policy is already installed", %{conn: conn} do
      post_conn = post(conn, trigger_policy_path(conn, :create, @realm), data: @valid_attrs)
      assert response(post_conn, 201) == ""

      post2_conn = post(conn, trigger_policy_path(conn, :create, @realm), data: @valid_attrs)
      assert json_response(post2_conn, 409)["errors"] != %{}
    end
  end
end
