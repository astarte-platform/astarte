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

  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Helpers.Database
  alias Astarte.RealmManagement.API.Helpers.JWTTestHelper
  alias Astarte.RealmManagement.API.Helpers.RPCMock.DB
  alias Astarte.RealmManagement.API.Triggers
  alias Astarte.RealmManagement.API.Triggers.Trigger
  alias Ecto.Changeset

  import Astarte.RealmManagement.API.Fixtures.Trigger

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

    test "lists all triggers after installing it", %{
      conn: conn,
      realm: realm,
      trigger_attrs: trigger_attrs,
      trigger_name: trigger_name
    } do
      conn = post(conn, trigger_path(conn, :create, realm), data: trigger_attrs)

      # TODO: remove once get trigger list rpc is removed
      create_trigger(realm, trigger_attrs)

      conn = get(conn, trigger_path(conn, :index, realm))
      assert json_response(conn, 200)["data"] == [trigger_name]
    end
  end

  describe "create trigger" do
    test "renders trigger when data is valid", %{
      conn: conn,
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

    test "renders errors when http method in action is invalid", %{conn: conn, realm: realm} do
      conn = post(conn, trigger_path(conn, :create, realm), data: invalid_http_method())

      assert json_response(conn, 422)["errors"]["action"] == %{
               "http_method" => ["is invalid"]
             }
    end

    test "renders errors when creating the same trigger twice", %{
      conn: conn,
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
      conn: conn,
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
      conn: conn,
      realm: realm,
      trigger_name: trigger_name
    } do
      delete_conn =
        delete(conn, trigger_path(conn, :delete, realm, trigger_name))

      assert json_response(delete_conn, 404)["errors"] == %{"detail" => "Trigger not found"}
    end
  end

  defp create_trigger(realm_name, trigger_attrs) do
    {:ok, trigger_params} =
      %Trigger{}
      |> Trigger.changeset(trigger_attrs, realm_name: realm_name)
      |> Changeset.apply_action(:insert)

    %{name: trigger_name, policy: policy_name, action: action, simple_triggers: simple_triggers} =
      trigger_params

    encoded_action = Jason.encode!(action)

    tagged_simple_triggers =
      Enum.map(
        simple_triggers,
        &SimpleTriggerConfig.to_tagged_simple_trigger/1
      )

    DB.install_trigger(
      realm_name,
      trigger_name,
      policy_name,
      encoded_action,
      tagged_simple_triggers
    )

    {:ok, trigger_params}
  end
end
