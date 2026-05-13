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

defmodule Astarte.Adapters.EngineTest do
  use ExUnit.Case, async: true

  alias Astarte.Adapters.Engine
  alias Astarte.Adapters.MissingFieldError

  describe "deep_get/2" do
    test "extracts value using an atom path" do
      assert Engine.deep_get(%{a: 42}, :a) == {:ok, 42}
    end

    test "returns the original map when path is empty" do
      assert Engine.deep_get(%{a: 42}, []) == {:ok, %{a: 42}}
    end

    test "extracts value using a single-element list path" do
      assert Engine.deep_get(%{a: 42}, [:a]) == {:ok, 42}
    end

    test "extracts value deep inside nested maps" do
      assert Engine.deep_get(%{a: %{b: %{c: 42}}}, [:a, :b, :c]) == {:ok, 42}
    end

    test "returns :error when the root key is missing" do
      assert Engine.deep_get(%{a: 42}, [:b]) == :error
    end

    test "returns :error when a nested key is missing" do
      assert Engine.deep_get(%{a: %{}}, [:a, :b]) == :error
    end

    test "returns :error when encountering a non-map node midway" do
      assert Engine.deep_get(%{a: "string"}, [:a, :b]) == :error
    end

    test "returns :error when the source is entirely nil or not a map" do
      assert Engine.deep_get(nil, [:a]) == :error
      assert Engine.deep_get([a: 1], [:a]) == :error
    end
  end

  describe "deep_put/3" do
    test "inserts value using an atom path" do
      assert Engine.deep_put(%{}, :a, 42) == %{a: 42}
    end

    test "inserts value using a single-element list path" do
      assert Engine.deep_put(%{}, [:a], 42) == %{a: 42}
    end

    test "inserts value deep into an existing nested structure" do
      assert Engine.deep_put(%{a: %{b: 1}}, [:a, :c], 42) == %{a: %{b: 1, c: 42}}
    end

    test "creates intermediate empty maps when path goes deeper than existing structure" do
      assert Engine.deep_put(%{}, [:a, :b, :c], 42) == %{a: %{b: %{c: 42}}}
    end

    test "overwrites non-map nodes with a new map to proceed with insertion" do
      assert Engine.deep_put(%{a: "old_string"}, [:a, :b], 42) == %{a: %{b: 42}}
    end
  end

  describe "process_field/7" do
    test "raises MissingFieldError when a strictly missing key is required" do
      assert_raise MissingFieldError, fn ->
        Engine.process_field(%{}, %{}, [:dest], [:src], :dest, true, nil)
      end
    end

    test "returns accumulator unchanged when a strictly missing key is optional" do
      assert Engine.process_field(%{keep: 1}, %{}, [:dest], [:src], :dest, false, nil) == %{
               keep: 1
             }
    end

    test "raises MissingFieldError when an existing key has a nil value and is required" do
      assert_raise MissingFieldError, fn ->
        Engine.process_field(%{}, %{src: nil}, [:dest], [:src], :dest, true, nil)
      end
    end

    test "returns accumulator unchanged when an existing key has a nil value and is optional" do
      assert Engine.process_field(%{keep: 1}, %{src: nil}, [:dest], [:src], :dest, false, nil) ==
               %{keep: 1}
    end

    test "inserts the extracted value directly when no custom function is provided" do
      assert Engine.process_field(%{}, %{src: 42}, [:dest], [:src], :dest, true, nil) == %{
               dest: 42
             }
    end

    test "executes the custom function with extracted value and full source map" do
      custom_fun = fn val, source_map ->
        assert source_map == %{src: 10, other: 5}
        val * 2
      end

      assert Engine.process_field(
               %{},
               %{src: 10, other: 5},
               [:dest],
               [:src],
               :dest,
               true,
               custom_fun
             ) == %{dest: 20}
    end

    test "returns :error when the first key of a multi-part path is missing (triggers continue_get error fallback)" do
      assert Engine.deep_get(%{}, [:a, :b]) == :error
    end
  end
end
