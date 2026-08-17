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

defmodule Astarte.DataAccess.Config.XandraNodesTest do
  use ExUnit.Case, async: true
  alias Astarte.DataAccess.Config.XandraNodes

  describe "cast/1" do
    test "returns error for empty string" do
      assert XandraNodes.cast("") == :error
    end

    test "returns error for non-binary value" do
      assert XandraNodes.cast(nil) == :error
      assert XandraNodes.cast(123) == :error
      assert XandraNodes.cast([]) == :error
      assert XandraNodes.cast(:atom) == :error
    end

    test "parses a single node" do
      assert XandraNodes.cast("localhost:9042") == {:ok, ["localhost:9042"]}
    end

    test "parses multiple comma-separated nodes" do
      assert XandraNodes.cast("node1:9042,node2:9042,node3:9042") ==
               {:ok, ["node1:9042", "node2:9042", "node3:9042"]}
    end

    test "trims whitespace around node entries" do
      assert XandraNodes.cast("  node1:9042  ,  node2:9042  ") ==
               {:ok, ["node1:9042", "node2:9042"]}
    end

    test "trims trailing commas" do
      assert XandraNodes.cast("node1:9042,node2:9042,") ==
               {:ok, ["node1:9042", "node2:9042"]}
    end
  end
end
