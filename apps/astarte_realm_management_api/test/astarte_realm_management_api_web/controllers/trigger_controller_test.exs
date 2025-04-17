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

  alias Astarte.RealmManagement.API.Helpers.JWTTestHelper
  alias Astarte.RealmManagement.API.Helpers.RPCMock.DB

  @create_attrs %{}
  @invalid_attrs %{}

  @test_realm "test"

  setup %{conn: conn} do
    DB.put_jwt_public_key_pem(@test_realm, JWTTestHelper.public_key_pem())
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @tag :wip
  describe "index" do
    test "lists all triggers", %{conn: conn} do
      conn = get(conn, trigger_path(conn, :index, @test_realm))
      assert json_response(conn, 200)["data"] == []
    end
  end

  @tag :wip
  describe "create trigger" do
    test "renders trigger when data is valid", %{conn: conn} do
      conn = post(conn, trigger_path(conn, :create, @test_realm), trigger: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, trigger_path(conn, :show, id, @test_realm))
      assert json_response(conn, 200)["data"] == %{"id" => id}
    end
  end

  @tag :wip
  describe "update trigger" do
    test "renders errors when data is invalid", %{conn: conn, trigger: trigger} do
      conn = put(conn, trigger_path(conn, :update, trigger, @test_realm), trigger: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
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
