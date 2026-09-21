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

defmodule Astarte.RPC.Config.ClusteringStrategyTest do
  use ExUnit.Case, async: true

  alias Astarte.RPC.Config.ClusteringStrategy

  describe "cast/1" do
    test "casts valid string values" do
      assert ClusteringStrategy.cast("none") == {:ok, :none}
      assert ClusteringStrategy.cast("kubernetes") == {:ok, :kubernetes}
      assert ClusteringStrategy.cast("docker-compose") == {:ok, :docker_compose}
    end

    test "casts valid atom values" do
      assert ClusteringStrategy.cast(:none) == {:ok, :none}
      assert ClusteringStrategy.cast(:kubernetes) == {:ok, :kubernetes}
      assert ClusteringStrategy.cast(:docker_compose) == {:ok, :docker_compose}
    end

    test "returns error for invalid string values" do
      assert ClusteringStrategy.cast("invalid") == :error
      assert ClusteringStrategy.cast("unknown") == :error
    end

    test "returns error for invalid atom values" do
      assert ClusteringStrategy.cast(:invalid) == :error
      assert ClusteringStrategy.cast(:unknown) == :error
    end

    test "returns error for non-string, non-atom values" do
      assert ClusteringStrategy.cast(123) == :error
      assert ClusteringStrategy.cast([]) == :error
      assert ClusteringStrategy.cast(%{}) == :error
      assert ClusteringStrategy.cast(nil) == :error
    end
  end
end
