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

defmodule Astarte.TestSuite.Helpers.GroupTest do
  use ExUnit.Case, async: true

  import Astarte.TestSuite.CaseContext

  alias Astarte.Core.Interface
  alias Astarte.TestSuite.Helpers.Group, as: GroupHelper

  describe "groups/1" do
    test "creates generated groups in the canonical graph" do
      context = GroupHelper.groups(graph_context())

      assert map_size(context.groups) == 1

      [{group_id, {%{device_ids: [device_id], name: "group-4"}, owner_id}}] =
        Map.to_list(context.groups)

      assert group_id == owner_id <> ":group-4"
      assert owner_id == "AAAAAAAAAAAAAAAAAAAAAA"
      assert device_id == <<0::128>>
    end
  end

  describe "data/1" do
    test "sets persistence state for an empty graph" do
      context = GroupHelper.data(%{devices: %{}, groups: %{}, interfaces: %{}})

      assert context.groups_ready?
      assert context.group_database_results == []
    end
  end

  defp graph_context do
    %{}
    |> put!(:instances, "astarte1", "astarte1", nil)
    |> put!(:realms, "realm1", %{id: "realm1", instance_id: "astarte1"}, "astarte1")
    |> put!(:interfaces, "interface", %Interface{name: "interface"}, "realm1")
    |> put!(
      :devices,
      "AAAAAAAAAAAAAAAAAAAAAA",
      %{device_id: <<0::128>>, encoded_id: "AAAAAAAAAAAAAAAAAAAAAA"},
      "interface"
    )
    |> Map.put(:group_name, "group-4")
  end
end
