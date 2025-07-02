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

defmodule Astarte.RealmManagementWeb.TriggerPolicyControllerTest do
  use Astarte.Cases.Data, async: true
  use Astarte.RealmManagementWeb.ConnCase
  @moduletag :trigger_policy

  alias Astarte.Core.Generators.Triggers.Policy, as: PolicyGenerator
  alias Astarte.RealmManagement.Triggers.Policies
  alias Astarte.Helpers.Policy, as: PolicyHelper

  import ExUnit.CaptureLog

  @invalid_attrs %{
    "name" => "@invalid",
    "maximum_capacity" => 100,
    "error_handlers" => [
      %{"on" => "any_error", "strategy" => "discard"}
    ]
  }

  describe "index" do
    @describetag :index

    test "returns empty list", %{auth_conn: conn, realm: realm} do
      conn = get(conn, trigger_policy_path(conn, :index, realm))
      assert json_response(conn, 200)["data"] == []
    end

    test "list existing policies", %{auth_conn: conn, realm: realm} do
      policy = PolicyGenerator.policy() |> Enum.at(0)
      policy_map = PolicyHelper.policy_struct_to_map(policy)

      post_conn = post(conn, trigger_policy_path(conn, :create, realm), data: policy_map)
      assert json_response(post_conn, 201)["data"]["name"] == policy.name

      conn = get(conn, trigger_policy_path(conn, :index, realm))
      assert json_response(conn, 200)["data"] == [policy.name]

      capture_log(fn ->
        Policies.delete_trigger_policy(realm, policy.name)
      end)
    end
  end

  describe "show" do
    @describetag :show

    test "shows existing policy", %{auth_conn: conn, realm: realm} do
      policy = PolicyGenerator.policy() |> Enum.at(0)
      policy_map = PolicyHelper.policy_struct_to_map(policy)

      post_conn = post(conn, trigger_policy_path(conn, :create, realm), data: policy_map)
      assert json_response(post_conn, 201)["data"]["name"] == policy.name

      show_conn = get(conn, trigger_policy_path(conn, :show, realm, policy.name))

      assert json_response(show_conn, 200)["data"]["name"] == policy.name

      capture_log(fn ->
        Policies.delete_trigger_policy(realm, policy.name)
      end)
    end

    test "renders error on non-existing policy", %{auth_conn: conn, realm: realm} do
      conn = get(conn, trigger_policy_path(conn, :show, realm, "nonexisting"))

      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  describe "create policy" do
    @describetag :creation

    test "renders policy when data is valid", %{auth_conn: conn, realm: realm} do
      policy = PolicyGenerator.policy() |> Enum.at(0)
      policy_map = PolicyHelper.policy_struct_to_map(policy)

      post_conn = post(conn, trigger_policy_path(conn, :create, realm), data: policy_map)
      assert json_response(post_conn, 201)["data"]["name"] == policy.name

      get_conn = get(conn, trigger_policy_path(conn, :show, realm, policy.name))

      assert json_response(get_conn, 200)["data"]["name"] == policy.name

      capture_log(fn ->
        Policies.delete_trigger_policy(realm, policy.name)
      end)
    end

    test "renders errors when data is invalid", %{auth_conn: conn, realm: realm} do
      conn = post(conn, trigger_policy_path(conn, :create, realm), data: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders error when policy is already installed", %{auth_conn: conn, realm: realm} do
      policy = PolicyGenerator.policy() |> Enum.at(0)
      policy_map = PolicyHelper.policy_struct_to_map(policy)

      post_conn = post(conn, trigger_policy_path(conn, :create, realm), data: policy_map)
      assert json_response(post_conn, 201)["data"]["name"] == policy.name

      post2_conn = post(conn, trigger_policy_path(conn, :create, realm), data: policy_map)
      assert json_response(post2_conn, 409)["errors"] != %{}

      capture_log(fn ->
        Policies.delete_trigger_policy(realm, policy.name)
      end)
    end
  end

  describe "delete policy" do
    @describetag :deletion

    test "deletes existing policy", %{auth_conn: conn, realm: realm} do
      policy = PolicyGenerator.policy() |> Enum.at(0)
      policy_map = PolicyHelper.policy_struct_to_map(policy)

      post_conn = post(conn, trigger_policy_path(conn, :create, realm), data: policy_map)
      assert json_response(post_conn, 201)["data"]["name"] == policy.name

      delete_conn =
        delete(conn, trigger_policy_path(conn, :delete, realm, policy.name),
          async_operation: "false"
        )

      assert response(delete_conn, 204)

      get_conn = get(conn, trigger_policy_path(conn, :show, realm, policy.name))
      assert json_response(get_conn, 404)["errors"] != %{}
    end

    test "renders error when deleting non-existing policy", %{auth_conn: conn, realm: realm} do
      conn = delete(conn, trigger_policy_path(conn, :delete, realm, "nonexisting"))
      assert json_response(conn, 404)["errors"] != %{}
    end
  end
end
