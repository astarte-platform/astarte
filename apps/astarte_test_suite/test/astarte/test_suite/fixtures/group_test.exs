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

defmodule Astarte.TestSuite.Fixtures.GroupTest do
  use ExUnit.Case, async: true

  alias Astarte.TestSuite.Fixtures.Group, as: GroupFixtures

  describe "data/1" do
    test "sets persistence state for an empty graph" do
      context = context()

      assert context.groups_ready?
      assert context.group_database_results == []
    end
  end

  defp context,
    do: GroupFixtures.data(%{devices: %{}, groups: %{}, interfaces: %{}}) |> elem(1)
end
