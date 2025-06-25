#
# This file is part of Astarte.
#
# Copyright 2021 - 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.API.Triggers.Policies.PolicyTest do
  use Astarte.RealmManagement.API.DataCase, async: true
  use ExUnitProperties

  @moduletag :trigger_policy
  alias Astarte.Helpers.Database
  alias Astarte.RealmManagement
  alias Astarte.RealmManagement.API.Triggers.Policies
  alias Astarte.Core.Generators.Triggers.Policy, as: PolicyGenerator
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Policy.Handler
  alias Astarte.Core.Triggers.Policy.ErrorKeyword
  alias Astarte.Core.Triggers.Policy.ErrorRange
  alias Astarte.RealmManagement.Engine
  alias Astarte.RealmManagement.API.Helpers.RPCMock.DB

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
      check all(policy_struct <- PolicyGenerator.policy()) do
        policy_map = policy_struct_to_map(policy_struct)

        name = policy_map.name

        assert {:ok, %Policy{name: ^name}} = Policies.create_trigger_policy(realm, policy_map)

        RealmManagement.Engine.delete_trigger_policy(realm, name)
      end
    end

    test "fails with invalid attributes", %{realm: realm} do
      assert {:error, %Ecto.Changeset{errors: _}} =
               Policies.create_trigger_policy(realm, @invalid_attrs)
    end

    test "fails when policy already exists", %{realm: realm} do
      assert {:ok, %Policy{}} = Policies.create_trigger_policy(realm, @valid_attrs)

      assert {:error, :trigger_policy_already_present} =
               Policies.create_trigger_policy(realm, @valid_attrs)

      RealmManagement.Engine.delete_trigger_policy(realm, @policy_name)
    end
  end

  describe "Policy listing" do
    @describetag :policy_listing
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

    test "lists installed policies", %{realm: realm, policy: policy} do
      assert [policy.name] == Policies.list_trigger_policies(realm)
    end
  end

  describe "Policy source retrieval" do
    @describetag :policy_source

    test "retrieves source for installed policy", %{realm: realm} do
      assert {:ok, %Policy{}} = Policies.create_trigger_policy(realm, @valid_attrs)
      install_trigger_policy(realm, @valid_attrs)
      assert {:ok, json} = Policies.get_trigger_policy_source(realm, @policy_name)
      assert {:ok, %{name: @policy_name}} = Jason.decode(json, keys: :atoms)
      RealmManagement.Engine.delete_trigger_policy(realm, @policy_name)
    end

    test "fails when policy is not installed", %{realm: realm} do
      assert {:error, :trigger_policy_not_found} =
               Policies.get_trigger_policy_source(realm, "nonexistent_policy")
    end
  end

  describe "Policy deletion" do
    @describetag :deletion

    property "successfully deletes installed policies", %{realm: realm} do
      check all(policy_struct <- PolicyGenerator.policy()) do
        policy_map = policy_struct_to_map(policy_struct)

        name = policy_map.name

        assert {:ok, %Policy{name: ^name}} = Policies.create_trigger_policy(realm, policy_map)
        assert {:ok, :started} = Policies.delete_trigger_policy(realm, name)
        # todo delete once migration is completed
        Engine.delete_trigger_policy(realm, name)

        assert {:error, :trigger_policy_not_found} =
                 Policies.get_trigger_policy_source(realm, name)
      end
    end

    test "fails when policy is not installed", %{realm: realm} do
      assert {:error, :trigger_policy_not_found} =
               Policies.delete_trigger_policy(realm, "nonexistent_policy")
    end
  end

  # TODO: Remove this function when changeset generators are exposed on astarte_generators
  defp policy_struct_to_map(%Policy{} = policy_struct) do
    policy_struct
    |> Map.from_struct()
    |> Map.update!(:error_handlers, fn handlers ->
      Enum.map(handlers, fn %Handler{on: on, strategy: strategy} ->
        on_map =
          case on do
            %ErrorKeyword{keyword: keyword} -> %{on: keyword}
            %ErrorRange{error_codes: codes} -> %{on: codes}
          end

        Map.put(on_map, :strategy, strategy)
      end)
    end)
  end

  defp install_trigger_policy(realm, params) do
    {:ok, policy} = Policy.changeset(%Policy{}, params) |> Ecto.Changeset.apply_action(:insert)

    DB.install_trigger_policy(realm, policy)
  end
end
