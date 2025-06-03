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
  use Astarte.RealmManagement.APIWeb.ConnCase, async: true

  @moduletag :triggers

  alias Astarte.RealmManagement.API.Helpers.JWTTestHelper
  alias Astarte.RealmManagement.API.Helpers.RPCMock.DB

  import Astarte.RealmManagement.API.Fixtures.Trigger

  @trigger_name valid_trigger_attrs()["name"]

  setup %{conn: conn, realm: realm} do
    DB.put_jwt_public_key_pem(realm, JWTTestHelper.public_key_pem())
    token = JWTTestHelper.gen_jwt_all_access_token()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn}
  end

  describe "index" do
    test "lists all triggers", %{conn: conn, realm: realm} do
      conn = get(conn, trigger_path(conn, :index, realm))
      assert json_response(conn, 200)["data"] == []
    end

    test "lists all triggers after installing it", %{conn: conn, realm: realm} do
      conn = post(conn, trigger_path(conn, :create, realm), data: valid_trigger_attrs())
      conn = get(conn, trigger_path(conn, :index, realm))
      assert json_response(conn, 200)["data"] == [@trigger_name]
    end
  end

  describe "create trigger" do
    test "renders trigger when data is valid", %{conn: conn, realm: realm} do
      conn = post(conn, trigger_path(conn, :create, realm), data: valid_trigger_attrs())
      assert json_response(conn, 201)["data"]["name"] == @trigger_name

      conn = get(conn, trigger_path(conn, :show, realm, @trigger_name))

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

    test "renders errors when http method in action is invalid", %{conn: conn, realm: realm} do
      conn = post(conn, trigger_path(conn, :create, realm), data: invalid_http_method())

      assert json_response(conn, 422)["errors"]["action"] == %{
               "http_method" => ["is invalid"]
             }
    end

    test "renders errors when creating the same trigger twice", %{conn: conn, realm: realm} do
      post_conn =
        post(conn, trigger_path(conn, :create, realm), data: valid_trigger_attrs())

      assert json_response(post_conn, 201)["data"]["name"] == @trigger_name

      post_conn =
        post(conn, trigger_path(conn, :create, realm), data: valid_trigger_attrs())

      assert json_response(post_conn, 409)["errors"] == %{"detail" => "Trigger already exists"}
    end
  end

  describe "delete" do
    test "deletes trigger", %{conn: conn, realm: realm} do
      post_conn =
        post(conn, trigger_path(conn, :create, realm), data: valid_trigger_attrs())

      response = json_response(post_conn, 201)["data"]

      delete_conn =
        delete(conn, trigger_path(conn, :delete, realm, valid_trigger_attrs()["name"]))

      assert response(delete_conn, 204)
    end

    test "renders error when trigger doesn't exist", %{conn: conn, realm: realm} do
      delete_conn =
        delete(conn, trigger_path(conn, :delete, realm, valid_trigger_attrs()["name"]))

      assert json_response(delete_conn, 404)["errors"] == %{"detail" => "Trigger not found"}
    end
  end
end
