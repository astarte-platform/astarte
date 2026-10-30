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

defmodule Astarte.TestSuite.Helpers.SimpleTriggerTest do
  use ExUnit.Case, async: true

  import Astarte.TestSuite.CaseContext

  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.Trigger
  alias Astarte.TestSuite.Helpers.SimpleTrigger, as: SimpleTriggerHelper

  describe "simple_triggers/1" do
    test "creates correlated realm-wide simple triggers in the canonical graph" do
      %{simple_triggers: simple_triggers} =
        SimpleTriggerHelper.simple_triggers(graph_context())

      assert map_size(simple_triggers) == 1

      [{id, {simple_trigger, owner_id}}] = Map.to_list(simple_triggers)

      assert %{
               simple_trigger_config: %SimpleTriggerConfig{
                 device_id: device_id,
                 group_name: group_name,
                 interface_name: interface_name
               },
               trigger_target: %AMQPTriggerTarget{
                 parent_trigger_id: parent_trigger_id,
                 simple_trigger_id: simple_trigger_id
               }
             } = simple_trigger

      assert id == Ecto.UUID.load!(simple_trigger_id)
      assert parent_trigger_id == <<1::128>>
      assert simple_trigger_id == <<0::128>>
      assert owner_id == "trigger"
      assert is_nil(device_id)
      assert is_nil(group_name)
      assert interface_name in [nil, "*"]
    end
  end

  describe "data/1" do
    test "sets persistence state for an empty graph" do
      context = SimpleTriggerHelper.data(%{simple_triggers: %{}, triggers: %{}})

      assert context.simple_triggers_registered?
      assert context.simple_trigger_database_results == []
    end
  end

  defp graph_context do
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
