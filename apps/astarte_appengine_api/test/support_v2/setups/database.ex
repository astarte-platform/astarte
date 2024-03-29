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

defmodule Astarte.Test.Setups.Database do
  use ExUnit.Case, async: false
  alias Astarte.Test.Generators.Common, as: CommonGenerator
  alias Astarte.Test.Helpers.Database, as: DatabaseHelper
  alias Astarte.Test.Helpers.JWT, as: JWTHelper

  def connect(_context) do
    {:ok, cluster: :xandra}
  end

  def keyspace(_context) do
    {:ok, keyspace: CommonGenerator.keyspace_name() |> Enum.at(0)}
  end

  def setup(%{cluster: cluster, keyspace: keyspace}) do
    on_exit(fn ->
      DatabaseHelper.destroy_test_keyspace!(cluster, keyspace)
    end)

    DatabaseHelper.create_test_keyspace!(cluster, keyspace)
    {:ok, keyspace: keyspace}
  end

  def setup_auth(%{cluster: cluster, keyspace: keyspace}) do
    on_exit(fn ->
      DatabaseHelper.delete!(:pubkeypem, cluster, keyspace)
    end)

    DatabaseHelper.insert!(:pubkeypem, cluster, keyspace, JWTHelper.public_key_pem())
    {:ok, keyspace: keyspace}
  end
end
