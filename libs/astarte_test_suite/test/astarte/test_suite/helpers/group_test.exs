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

defmodule Astarte.TestSuite.Helpers.GroupTest do
  use ExUnit.Case, async: true

  import Astarte.TestSuite.CaseContext

  alias Astarte.Core.Interface
  alias Astarte.TestSuite.Helpers.Group, as: GroupHelper

  test "group helper sets group flag" do
    assert context().groups_ready?
  end

  test "group helper creates canonical graph groups" do
    assert GroupHelper.groups(graph_context()).groups == %{
             "device.group-4" =>
               {%{id: "device.group-4", name: "group-4", device_id: "device"}, "device"}
           }
  end

  defp context do
    %{devices_registered?: true, groups: %{"group1" => {%{id: "group1"}, "device"}}}
    |> GroupHelper.data()
  end

  defp graph_context do
    %{}
    |> put!(:instances, "astarte1", "astarte1", nil)
    |> put!(:realms, "realm1", %{id: "realm1", instance_id: "astarte1"}, "astarte1")
    |> put!(:interfaces, "interface", %Interface{name: "interface"}, "realm1")
    |> put!(:devices, "device", %{name: "device"}, "interface")
    |> Map.put(:group_name, "group-4")
  end
end
