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

defmodule Astarte.Test.Setups.Interface do
  use ExUnit.Case, async: false
  alias Astarte.Test.Helpers.Database, as: DatabaseHelper
  alias Astarte.Test.Generators.Interface, as: InterfaceGenerator

  def init(%{interface_count: interface_count}) do
    {:ok, interfaces: InterfaceGenerator.interface() |> Enum.take(interface_count)}
  end

  def setup(%{cluster: cluster, keyspace: keyspace, interfaces: interfaces}) do
    on_exit(fn ->
      DatabaseHelper.delete!(:interface, cluster, keyspace, interfaces)
    end)

    DatabaseHelper.insert!(:interface, cluster, keyspace, interfaces)
    :ok
  end
end
