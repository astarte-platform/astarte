#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.Core.Adapters.Triggers.PolicyTest do
  use ExUnit.Case
  use ExUnitProperties

  import Astarte.Core.Generators.Triggers.Policy

  import Astarte.Core.Adapters.Triggers.Policy

  alias Astarte.Core.Triggers.Policy

  alias Ecto.Changeset

  @moduletag :core
  @moduletag :triggers
  @moduletag :policy
  describe "trigger policy adapters" do
    property "changeset is valid" do
      check all policy <- policy() do
        changeset = Policy.changeset(%Policy{}, from_core_triggers_policy_to_change(policy))

        assert %Changeset{valid?: true} = changeset,
               "Invalid policy: #{inspect(changeset.errors)}"
      end
    end
  end
end
