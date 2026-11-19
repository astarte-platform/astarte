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

defmodule Astarte.TestSuite.Cases.PolicyTest do
  use ExUnit.Case, async: true

  import Astarte.TestSuite.CaseContext

  alias Astarte.Core.Triggers.Policy
  alias Astarte.TestSuite.Cases.Policy, as: PolicyCase

  describe "normalize_config!/2" do
    test "normalizes policy defaults" do
      context = PolicyCase.normalize_config!([], realm_context())

      assert context.policy_number == 1
      assert map_size(context.policies) == 1
    end

    test "normalizes explicit policies" do
      policies = %{"policy" => {%Policy{name: "policy"}, "realm"}}

      context =
        PolicyCase.normalize_config!(
          [policy_number: 2, policies: policies],
          realm_context()
        )

      assert context.policy_number == 2
      assert context.policies == policies
    end
  end

  defp realm_context do
    %{}
    |> put!(:instances, "astarte", "astarte", nil)
    |> put!(:realms, "realm", %{id: "realm", instance_id: "astarte"}, "astarte")
  end
end
