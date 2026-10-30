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

defmodule Astarte.TestSuite.Helpers.TriggerTest do
  use ExUnit.Case, async: true

  import Astarte.TestSuite.CaseContext

  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.Trigger
  alias Astarte.TestSuite.Helpers.Trigger, as: TriggerHelper

  describe "triggers/1" do
    test "creates generated triggers in the canonical graph" do
      %{triggers: triggers} = TriggerHelper.triggers(graph_context())

      assert map_size(triggers) == 2

      for {trigger_id, {%Trigger{name: name, policy: policy}, owner_id}} <- triggers do
        assert trigger_id == owner_id <> ":" <> name
        assert policy == "policy"
        assert owner_id == "realm"
      end
    end

    test "creates triggers without a policy when none is configured" do
      %{triggers: triggers} =
        graph_context()
        |> Map.delete(:policies)
        |> TriggerHelper.triggers()

      for {_trigger_id, {%Trigger{policy: policy}, _owner_id}} <- triggers do
        assert is_nil(policy)
      end
    end

    test "uses only policies owned by each realm" do
      %{triggers: triggers} =
        graph_context()
        |> put!(:realms, "realm-without-policy", %{id: "realm-without-policy"}, "astarte")
        |> Map.put(:trigger_number, 1)
        |> TriggerHelper.triggers()

      assert map_size(triggers) == 2

      for {_trigger_id, {%Trigger{policy: policy}, owner_id}} <- triggers do
        if owner_id == "realm" do
          assert policy == "policy"
        else
          assert owner_id == "realm-without-policy"
          assert is_nil(policy)
        end
      end
    end
  end

  describe "data/1" do
    test "sets persistence state for an empty graph" do
      context = TriggerHelper.data(%{triggers: %{}})

      assert context.triggers_registered?
      assert context.trigger_database_results == []
    end
  end

  defp graph_context do
    %{}
    |> put!(:instances, "astarte", "astarte", nil)
    |> put!(:realms, "realm", %{id: "realm", instance_id: "astarte"}, "astarte")
    |> put!(:policies, "policy", %Policy{name: "policy"}, "realm")
    |> Map.put(:trigger_number, 2)
  end
end
