# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Core.Generators.Triggers.PolicyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Generators.Triggers.Policy, as: PolicyGenerator
  alias Astarte.Core.Triggers.Policy

  @moduletag :trigger
  @moduletag :policy

  @doc false
  describe "triggers policy generator" do
    @describetag :success
    @describetag :ut

    property "generates valid policies using to_changes (gen)" do
      gen_policy_changes = PolicyGenerator.policy() |> PolicyGenerator.to_changes()

      check all changes <- gen_policy_changes,
                changeset = Policy.changeset(%Policy{}, changes) do
        assert changeset.valid?, "Invalid policy: #{inspect(changeset.errors)}"
      end
    end

    property "generates valid policies using to_changes (struct)" do
      check all policy <- PolicyGenerator.policy(),
                changes <- PolicyGenerator.to_changes(policy),
                changeset = Policy.changeset(%Policy{}, changes) do
        assert changeset.valid?, "Invalid policy: #{inspect(changeset.errors)}"
      end
    end
  end
end
