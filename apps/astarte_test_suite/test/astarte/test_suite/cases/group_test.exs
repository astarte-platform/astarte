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

defmodule Astarte.TestSuite.Cases.GroupTest do
  use ExUnit.Case, async: true

  alias Astarte.TestSuite.Cases.Group, as: GroupCase

  describe "normalize_config!/2" do
    test "normalizes group defaults" do
      context = GroupCase.normalize_config!([], device_context())

      assert context.group_number == 1
      assert context.group_name == "group-1"
      assert map_size(context.groups) == 1
    end

    test "normalizes group configuration with derived default" do
      context = GroupCase.normalize_config!([group_number: 4], device_context())

      assert context.group_number == 4
      assert context.group_name == "group-4"
    end

    test "keeps explicit group name" do
      context =
        GroupCase.normalize_config!(
          [group_number: 4, group_name: "custom"],
          device_context()
        )

      assert context.group_number == 4
      assert context.group_name == "custom"
    end
  end

  defp device_context do
    %{
      devices: %{
        "AAAAAAAAAAAAAAAAAAAAAA" =>
          {%{device_id: <<0::128>>, encoded_id: "AAAAAAAAAAAAAAAAAAAAAA"}, "interface"}
      }
    }
  end
end
