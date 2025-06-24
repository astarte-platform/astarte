#
# This file is part of Astarte.
#
# Copyright 2022 - 2025 SECO Mind Srl
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
  use Astarte.RealmManagement.API.DataCase, async: true
  use Astarte.RealmManagement.APIWeb.ConnCase
  @moduletag :trigger_policy

  alias Astarte.Core.Generators.Triggers.Policy, as: PolicyGenerator
  alias Astarte.RealmManagement
  alias Astarte.Helpers.Database
  alias Astarte.RealmManagement.API.Helpers.JWTTestHelper
  alias Astarte.RealmManagement.API.Helpers.RPCMock.DB
  alias Astarte.RealmManagement.Engine
  alias Astarte.Core.Triggers.Policy

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
    @describetag :index

    setup %{realm: realm, astarte_instance_id: astarte_instance_id} do
      policy = PolicyGenerator.policy() |> Enum.at(0)
      policy_json = Jason.encode!(policy)
      # TODO: Replace when the trigger policy installation is moved to the API
      :ok = RealmManagement.Engine.install_trigger_policy(realm, policy_json)

      on_exit(fn ->
        Database.setup_database_access(astarte_instance_id)
        # TODO: change after removal of `delete_trigger_policy` rpc
        RealmManagement.Engine.delete_trigger_policy(realm, policy.name)
      end)

      %{policy: policy}
    end

    test "list existing policies", %{conn: conn, realm: realm, policy: policy} do
      conn = get(conn, trigger_policy_path(conn, :index, realm))
      assert json_response(conn, 200)["data"] == [policy.name]
    end
  end

  describe "show" do
    @describetag :show

    test "shows existing policy", %{conn: conn, realm: realm} do
      # TODO: uncomment after porting create_trigger_policy to rm_api
      # post_conn = post(conn, trigger_policy_path(conn, :create, realm), data: @valid_attrs)
      # assert json_response(post_conn, 201)["data"]["name"] == @policy_name
      # 
      # 
      install_trigger_policy(realm, @valid_attrs)
      show_conn = get(conn, trigger_policy_path(conn, :show, realm, @policy_name))

      assert json_response(show_conn, 200)["data"]["name"] == @policy_name
    end

    test "renders error on non-existing policy", %{conn: conn, realm: realm} do
      conn = get(conn, trigger_policy_path(conn, :show, realm, "nonexisting"))

      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  describe "create policy" do
    @describetag :creation

    test "renders policy when data is valid", %{conn: conn, realm: realm} do
      # TODO: uncomment after porting create_trigger_policy to rm_api
      # post_conn = post(conn, trigger_policy_path(conn, :create, realm), data: @valid_attrs)
      # assert json_response(post_conn, 201)["data"]["name"] == @policy_name
      # 

      install_trigger_policy(realm, @valid_attrs)

      get_conn = get(conn, trigger_policy_path(conn, :show, realm, @policy_name))

      assert Map.take(json_response(get_conn, 200)["data"], Map.keys(@valid_attrs)) ==
               @valid_attrs
    end

    test "renders errors when data is invalid", %{conn: conn, realm: realm} do
      conn = post(conn, trigger_policy_path(conn, :create, realm), data: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders error when policy is already installed", %{conn: conn, realm: realm} do
      # TODO: uncomment after porting create_trigger_policy to rm_api
      # post_conn = post(conn, trigger_policy_path(conn, :create, realm), data: @valid_attrs)
      # assert json_response(post_conn, 201)["data"]["name"] == @policy_name
      # 

      install_trigger_policy(realm, @valid_attrs)

      post2_conn = post(conn, trigger_policy_path(conn, :create, realm), data: @valid_attrs)
      assert json_response(post2_conn, 409)["errors"] != %{}
    end
  end

  describe "delete policy" do
    @describetag :deletion

    test "deletes existing policy", %{conn: conn, realm: realm} do
      # TODO: uncomment after porting create_trigger_policy to rm_api
      # post_conn = post(conn, trigger_policy_path(conn, :create, realm), data: @valid_attrs)
      # assert json_response(post_conn, 201)["data"]["name"] == @policy_name
      # 

      install_trigger_policy(realm, @valid_attrs)

      delete_conn = delete(conn, trigger_policy_path(conn, :delete, realm, @policy_name))
      assert response(delete_conn, 204)
      # todo delete once migration is completed
      Engine.delete_trigger_policy(realm, @policy_name)
      get_conn = get(conn, trigger_policy_path(conn, :show, realm, @policy_name))
      assert json_response(get_conn, 404)["errors"] != %{}
    end

    test "renders error when deleting non-existing policy", %{conn: conn, realm: realm} do
      conn = delete(conn, trigger_policy_path(conn, :delete, realm, "nonexisting"))
      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  defp install_trigger_policy(realm, params) do
    {:ok, policy} = Policy.changeset(%Policy{}, params) |> Ecto.Changeset.apply_action(:insert)

    DB.install_trigger_policy(realm, policy)
  end
end
