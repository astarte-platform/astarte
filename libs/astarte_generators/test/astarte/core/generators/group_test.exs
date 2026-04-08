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

defmodule Astarte.Core.Generators.GroupTest do
  @moduledoc """
  Tests for Astarte Group generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Generators.Group, as: GroupGenerator

  @moduletag :group

  @doc false
  describe "group generator fields" do
    @tag :success
    property "success valid group name" do
      check all group_name <- GroupGenerator.name(), max_runs: 500 do
        assert String.first(group_name) not in ["@", "~", "\s"]
      end
    end
  end

  @doc false
  describe "group generator struct" do
    @tag :success
    property "success base group creation" do
      check all group <- GroupGenerator.group() do
        refute is_nil(group)
      end
    end
  end
end
