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

defmodule Astarte.RealmManagementWeb.TriggerControllerTest do
  use Astarte.Cases.Data, async: true
  use Astarte.RealmManagementWeb.ConnCase

  @moduletag :triggers

  alias Astarte.Helpers.Database
  alias Astarte.RealmManagement.Triggers
  alias Astarte.Helpers.Database

  import Astarte.RealmManagement.Fixtures.Trigger

  @trigger_name valid_trigger_attrs()["name"]

  setup context do
    %{realm: realm, astarte_instance_id: astarte_instance_id} = context
    trigger_attrs = valid_trigger_attrs()
    trigger_name = trigger_attrs["name"]

    on_exit(fn ->
      Database.setup_database_access(astarte_instance_id)

      with {:ok, trigger} <- Triggers.get_trigger(realm, trigger_name) do
        Triggers.delete_trigger(realm, trigger)
      end
    end)

    %{trigger_attrs: trigger_attrs, trigger_name: trigger_name}
  end

  describe "index" do
    test "lists all triggers", %{auth_conn: conn, realm: realm} do
      conn = get(conn, trigger_path(conn, :index, realm))
      assert json_response(conn, 200)["data"] == []
    end

    test "lists all triggers after installing it", %{
      auth_conn: conn,
      realm: realm,
      trigger_attrs: trigger_attrs,
      trigger_name: trigger_name
    } do
      conn = post(conn, trigger_path(conn, :create, realm), data: trigger_attrs)

      conn = get(conn, trigger_path(conn, :index, realm))
      assert json_response(conn, 200)["data"] == [trigger_name]
    end
  end

  describe "create trigger" do
    test "renders trigger when data is valid", %{
      auth_conn: conn,
      realm: realm,
      trigger_attrs: trigger_attrs,
      trigger_name: trigger_name
    } do
      conn = post(conn, trigger_path(conn, :create, realm), data: trigger_attrs)
      assert json_response(conn, 201)["data"]["name"] == trigger_name

      conn = get(conn, trigger_path(conn, :show, realm, trigger_name))

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

    test "renders errors when http method in action is invalid", %{auth_conn: conn, realm: realm} do
      conn = post(conn, trigger_path(conn, :create, realm), data: invalid_http_method())

      assert json_response(conn, 422)["errors"]["action"] == %{
               "http_method" => ["is invalid"]
             }
    end

    test "renders errors when creating the same trigger twice", %{
      auth_conn: conn,
      realm: realm,
      trigger_attrs: trigger_attrs,
      trigger_name: trigger_name
    } do
      post_conn =
        post(conn, trigger_path(conn, :create, realm), data: trigger_attrs)

      assert json_response(post_conn, 201)["data"]["name"] == trigger_name

      post_conn =
        post(conn, trigger_path(conn, :create, realm), data: trigger_attrs)

      assert json_response(post_conn, 409)["errors"] == %{"detail" => "Trigger already exists"}
    end
  end

  describe "delete" do
    test "deletes trigger", %{
      auth_conn: conn,
      realm: realm,
      trigger_attrs: trigger_attrs,
      trigger_name: trigger_name
    } do
      post_conn =
        post(conn, trigger_path(conn, :create, realm), data: trigger_attrs)

      assert json_response(post_conn, 201)

      delete_conn =
        delete(conn, trigger_path(conn, :delete, realm, trigger_name))

      assert response(delete_conn, 204)
    end

    test "renders error when trigger doesn't exist", %{
      auth_conn: conn,
      realm: realm,
      trigger_name: trigger_name
    } do
      delete_conn =
        delete(conn, trigger_path(conn, :delete, realm, trigger_name))

      assert json_response(delete_conn, 404)["errors"] == %{"detail" => "Trigger not found"}
    end
  end
end
