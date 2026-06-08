#
# This file is part of Astarte.
#
# Copyright 2021 - 2026 SECO Mind Srl
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

defmodule Astarte.RealmManagement.Triggers.Policies.PolicyTest do
  use ExUnitProperties

  use Astarte.Cases.Data, async: true

  import ExUnit.CaptureLog

  alias Astarte.Core.Triggers.Policy

  alias Astarte.Core.Generators.Triggers.Policy, as: PolicyGenerator

  alias Astarte.RealmManagement.Triggers.Policies

  @moduletag :trigger_policy

  @policy_name "policy_name"
  @valid_attrs %{
    name: @policy_name,
    maximum_capacity: 300,
    retry_times: 10,
    event_ttl: 10,
    error_handlers: [
      %{on: "any_error", strategy: "retry"}
    ]
  }
  @invalid_attrs %{
    "name" => "pippo",
    "maximum_capacity" => 100
  }

  describe "Policy creation" do
    @describetag :creation
    property "successfully creates and retrieves valid policies", %{realm: realm} do
      check all policy_changeset =
                  %{name: name} <- PolicyGenerator.policy() |> PolicyGenerator.to_changes() do
        assert {:ok, %Policy{name: ^name}} =
                 Policies.create_trigger_policy(realm, policy_changeset)

        capture_log(fn ->
          Policies.delete_trigger_policy(realm, name)
        end)
      end
    end

    test "fails with invalid attributes", %{realm: realm} do
      assert {:error, :invalid_trigger_policy} =
               Policies.create_trigger_policy(realm, @invalid_attrs)
    end

    test "fails when policy already exists", %{realm: realm} do
      assert {:ok, %Policy{}} = Policies.create_trigger_policy(realm, @valid_attrs)

      assert {:error, :trigger_policy_already_present} =
               Policies.create_trigger_policy(realm, @valid_attrs)

      capture_log(fn ->
        Policies.delete_trigger_policy(realm, @policy_name)
      end)
    end
  end

  describe "Policy listing" do
    @describetag :policy_listing

    test "lists installed policies", %{realm: realm} do
      policy_changeset =
        %{name: name} = PolicyGenerator.policy() |> PolicyGenerator.to_changes() |> Enum.at(0)

      {:ok, _created_policy} = Policies.create_trigger_policy(realm, policy_changeset)
      assert name in Policies.list_trigger_policies(realm)

      capture_log(fn ->
        Policies.delete_trigger_policy(realm, name)
      end)
    end
  end

  describe "Policy source retrieval" do
    @describetag :policy_source

    test "retrieves source for installed policy", %{realm: realm} do
      policy_changeset =
        %{name: name} = PolicyGenerator.policy() |> PolicyGenerator.to_changes() |> Enum.at(0)

      assert {:ok, %Policy{}} = Policies.create_trigger_policy(realm, policy_changeset)

      assert {:ok, json} = Policies.get_trigger_policy_source(realm, name)
      assert {:ok, %{name: ^name}} = Jason.decode(json, keys: :atoms)

      capture_log(fn ->
        Policies.delete_trigger_policy(realm, name)
      end)
    end

    test "fails when policy is not installed", %{realm: realm} do
      assert {:error, :trigger_policy_not_found} =
               Policies.get_trigger_policy_source(realm, "nonexistent_policy")
    end
  end

  describe "Policy deletion" do
    @describetag :deletion
    setup %{realm: realm} do
      policy_changeset = PolicyGenerator.policy() |> PolicyGenerator.to_changes() |> Enum.at(0)

      {:ok, created_policy} = Policies.create_trigger_policy(realm, policy_changeset)

      %{policy: created_policy}
    end

    test "successfully deletes installed policy", %{realm: realm, policy: %{name: name}} do
      assert :ok = Policies.delete_trigger_policy(realm, name)

      assert {:error, :trigger_policy_not_found} =
               Policies.get_trigger_policy_source(realm, name)
    end

    test "fails when policy is not installed", %{realm: realm} do
      assert {:error, :trigger_policy_not_found} =
               Policies.delete_trigger_policy(realm, "nonexistent_policy")
    end
  end
end
