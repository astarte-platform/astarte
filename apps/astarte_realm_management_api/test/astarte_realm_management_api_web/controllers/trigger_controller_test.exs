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

defmodule Astarte.RealmManagement.APIWeb.TriggerControllerTest do
  use Astarte.RealmManagement.APIWeb.ConnCase

  @moduletag :triggers

  alias Astarte.RealmManagement.API.Helpers.JWTTestHelper
  alias Astarte.RealmManagement.API.Helpers.RPCMock.DB

  import Astarte.RealmManagement.API.Fixtures.Trigger

  @trigger_name valid_trigger_attrs()["name"]
  @test_realm "test"

  setup %{conn: conn} do
    DB.put_jwt_public_key_pem(@test_realm, JWTTestHelper.public_key_pem())
    token = JWTTestHelper.gen_jwt_all_access_token()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn}
  end

  @tag :wip
  describe "index" do
    test "lists all triggers", %{conn: conn} do
      conn = get(conn, trigger_path(conn, :index, @test_realm))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create trigger" do
    test "renders trigger when data is valid", %{conn: conn} do
      conn = post(conn, trigger_path(conn, :create, @test_realm), data: valid_trigger_attrs())
      assert json_response(conn, 201)["data"]["name"] == @trigger_name

      conn = get(conn, trigger_path(conn, :show, @test_realm, @trigger_name))

      assert json_response(conn, 200)["data"] == %{
               "name" => @trigger_name,
               "action" => %{
                 "http_method" => "delete",
                 "http_url" => "http://www.example.com",
                 "ignore_ssl_errors" => false
               },
               "simple_triggers" => [
                 %{"device_id" => "*", "on" => "device_connected", "type" => "device_trigger"}
               ]
             }
    end

    test "renders errors when http method in action is invalid", %{conn: conn} do
      conn = post(conn, trigger_path(conn, :create, @test_realm), data: invalid_http_method())

      assert json_response(conn, 422)["errors"]["action"] == %{
               "http_method" => ["is invalid"]
             }
    end

    test "renders errors when creating the same trigger twice", %{conn: conn} do
      post_conn =
        post(conn, trigger_path(conn, :create, @test_realm), data: valid_trigger_attrs())

      assert json_response(post_conn, 201)["data"]["name"] == @trigger_name

      post_conn =
        post(conn, trigger_path(conn, :create, @test_realm), data: valid_trigger_attrs())

      assert json_response(post_conn, 409)["errors"] == %{"detail" => "Trigger already exists"}
    end
  end

  @tag :wip
  describe "delete trigger" do
    test "deletes chosen trigger", %{conn: conn, trigger: trigger} do
      conn = delete(conn, trigger_path(conn, :delete, trigger, @test_realm))
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, trigger_path(conn, :show, trigger, @test_realm))
      end)
    end
  end
end
