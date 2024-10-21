#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Astarte.Test.Setups.Group do
  use ExUnit.Case, async: false
  alias Astarte.Test.Helpers.Database, as: DatabaseHelper
  alias Astarte.Test.Generators.Group, as: GroupGenerator

  def init(%{group_count: group_count, devices: devices}) do
    {:ok, groups: GroupGenerator.group(devices: devices) |> Enum.take(group_count)}
  end

  def setup(%{cluster: cluster, keyspace: keyspace, groups: groups}) do
    on_exit(fn ->
      DatabaseHelper.delete!(:group, cluster, keyspace, groups)
    end)

    DatabaseHelper.insert!(:group, cluster, keyspace, groups)
    :ok
  end
end
