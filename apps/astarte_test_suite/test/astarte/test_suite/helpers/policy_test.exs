#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.TestSuite.Helpers.PolicyTest do
  use ExUnit.Case, async: true

  import Astarte.TestSuite.CaseContext

  alias Astarte.Core.Triggers.Policy
  alias Astarte.TestSuite.Helpers.Policy, as: PolicyHelper

  describe "policies/1" do
    test "creates generated policies in the canonical graph" do
      %{policies: policies} = PolicyHelper.policies(graph_context())

      assert map_size(policies) == 2

      for {policy_id, {%Policy{name: name}, owner_id}} <- policies do
        assert policy_id == owner_id <> ":" <> name
        assert owner_id == "realm"
      end
    end

    test "creates distinct graph entries for different realms" do
      context =
        graph_context()
        |> put!(:realms, "realm2", %{id: "realm2", instance_id: "astarte"}, "astarte")
        |> Map.put(:policy_number, 1)
        |> PolicyHelper.policies()

      assert map_size(context.policies) == 2
    end
  end

  describe "data/1" do
    test "sets persistence state for an empty graph" do
      context = PolicyHelper.data(%{policies: %{}})

      assert context.policies_registered?
      assert context.policy_database_results == []
    end
  end

  defp graph_context do
    %{}
    |> put!(:instances, "astarte", "astarte", nil)
    |> put!(:realms, "realm", %{id: "realm", instance_id: "astarte"}, "astarte")
    |> Map.put(:policy_number, 2)
  end
end
