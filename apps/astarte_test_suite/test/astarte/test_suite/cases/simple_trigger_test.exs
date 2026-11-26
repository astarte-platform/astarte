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

defmodule Astarte.TestSuite.Cases.SimpleTriggerTest do
  use ExUnit.Case, async: true

  import Astarte.TestSuite.CaseContext

  alias Astarte.Core.Triggers.Trigger
  alias Astarte.TestSuite.Cases.SimpleTrigger, as: SimpleTriggerCase

  describe "normalize_config!/2" do
    test "normalizes simple trigger defaults" do
      context = SimpleTriggerCase.normalize_config!([], trigger_context())

      assert map_size(context.simple_triggers) == 1
    end

    test "normalizes explicit simple triggers" do
      simple_triggers = %{"simple-trigger" => {%{}, "trigger"}}

      context =
        SimpleTriggerCase.normalize_config!(
          [simple_triggers: simple_triggers],
          trigger_context()
        )

      assert context.simple_triggers == simple_triggers
    end
  end

  defp trigger_context do
    %{}
    |> put!(:instances, "astarte", "astarte", nil)
    |> put!(:realms, "realm", %{id: "realm", instance_id: "astarte"}, "astarte")
    |> put!(
      :triggers,
      "trigger",
      %Trigger{
        name: "trigger",
        trigger_uuid: <<1::128>>,
        simple_triggers_uuids: [<<0::128>>]
      },
      "realm"
    )
  end
end
