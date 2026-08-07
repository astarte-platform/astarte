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
  use ExUnitProperties

  import Astarte.Adapters.Engine

  alias Astarte.Adapters.MissingFieldError

  describe "deep_get/2" do
    test "returns ok with data when path is empty list" do
      assert {:ok, %{a: 1}} == deep_get(%{a: 1}, [])
    end

    test "handles atom and binary paths" do
      assert {:ok, 1} == deep_get(%{a: 1}, :a)
      assert {:ok, 2} == deep_get(%{"b" => 2}, "b")
    end

    test "returns value for single key" do
      assert {:ok, 1} == deep_get(%{a: 1}, [:a])
      assert :error == deep_get(%{a: 1}, [:b])
    end

    test "returns value for nested keys" do
      assert {:ok, 1} == deep_get(%{a: %{b: 1}}, [:a, :b])
    end

    test "returns error when intermediate key is missing" do
      assert :error == deep_get(%{a: %{}}, [:a, :b, :c])
    end

    test "returns error when trying to get from a non-map" do
      assert :error == deep_get("not_a_map", [:a])
      assert :error == deep_get(%{a: "not_a_map"}, [:a, :b])
    end
  end

  describe "deep_put/3" do
    test "handles atom and binary paths" do
      assert %{a: 1} == deep_put(%{}, :a, 1)
      assert %{"b" => 2} == deep_put(%{}, "b", 2)
    end

    test "puts value for single key" do
      assert %{a: 1} == deep_put(%{}, [:a], 1)
    end

    test "puts value for nested keys" do
      assert %{a: %{b: %{c: 1}}} == deep_put(%{}, [:a, :b, :c], 1)
    end

    test "overwrites scalar value with map via ensure_map/1" do
      assert %{a: %{b: 2}} == deep_put(%{a: 1}, [:a, :b], 2)
    end
  end

  describe "process_field/7 and handle_fetched/8" do
    test "raises MissingFieldError when required field is missing" do
      assert_raise MissingFieldError, fn ->
        process_field(%{}, %{}, [:dest], [:src], :dest, true, nil)
      end
    end

    test "returns accumulator when optional field is missing" do
      acc = %{kept: 1}
      assert acc == process_field(acc, %{}, [:dest], [:src], :dest, false, nil)
    end

    test "applies arity 2 custom function" do
      fun = fn val, source -> val + source.offset end
      source = %{src: 10, offset: 5}
      expected = %{dest: 15}
      assert expected == process_field(%{}, source, [:dest], [:src], :dest, true, fun)
    end

    test "applies arity 1 custom function with empty source path (entire source passed)" do
      fun = fn source -> source.a + source.b end
      source = %{a: 10, b: 5}
      expected = %{dest: 15}
      assert expected == process_field(%{}, source, [:dest], [], :dest, true, fun)
    end

    test "applies arity 1 custom function with specific source path" do
      fun = fn val -> val * 2 end
      source = %{src: 10}
      expected = %{dest: 20}
      assert expected == process_field(%{}, source, [:dest], [:src], :dest, true, fun)
    end

    test "raises MissingFieldError when required field is nil and no custom fun" do
      assert_raise MissingFieldError, fn ->
        process_field(%{}, %{src: nil}, [:dest], [:src], :dest, true, nil)
      end
    end

    test "returns accumulator when optional field is nil and no custom fun" do
      acc = %{kept: 1}
      assert acc == process_field(acc, %{src: nil}, [:dest], [:src], :dest, false, nil)
    end

    test "puts value directly when no custom function is provided" do
      source = %{src: 10}
      expected = %{dest: 10}
      assert expected == process_field(%{}, source, [:dest], [:src], :dest, true, nil)
    end

    test "raises ArgumentError with arity info when custom function has invalid arity" do
      fun = fn a, b, c -> a + b + c end

      assert_raise ArgumentError, ~r/Expected arity 1 or 2, got: arity 3/, fn ->
        process_field(%{}, %{src: 1}, [:dest], [:src], :dest, true, fun)
      end
    end

    test "raises ArgumentError with inspect info when custom function is not a function" do
      assert_raise ArgumentError, ~r/Expected arity 1 or 2, got: "not a function"/, fn ->
        process_field(%{}, %{src: 1}, [:dest], [:src], :dest, true, "not a function")
      end
    end
  end

  describe "Properties" do
    property "deep_put followed by deep_get retrieves the exact value" do
      check all path <- list_of(one_of([atom(:alphanumeric), string(:ascii)]), min_length: 1),
                value <- term(),
                map <- map_of(atom(:alphanumeric), term()) do
        updated_map = deep_put(map, path, value)
        assert {:ok, value} == deep_get(updated_map, path)
      end
    end
  end
end
