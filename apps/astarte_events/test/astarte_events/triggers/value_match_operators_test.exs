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

defmodule Astarte.Events.Triggers.ValueMatchOperatorsTest do
  use ExUnit.Case, async: true

  alias Astarte.Events.Triggers.ValueMatchOperators, as: VMO

  describe "ANY operator" do
    test "always matches regardless of values" do
      assert VMO.value_matches?(123, :ANY, 456)
      assert VMO.value_matches?(nil, :ANY, "whatever")
      assert VMO.value_matches?("foo", :ANY, nil)
    end
  end

  describe "nil received value" do
    test "never matches for operators other than ANY" do
      refute VMO.value_matches?(nil, :EQUAL_TO, 1)
      refute VMO.value_matches?(nil, :NOT_EQUAL_TO, 1)
      refute VMO.value_matches?(nil, :GREATER_THAN, 1)
      refute VMO.value_matches?(nil, :CONTAINS, "a")
    end
  end

  describe "equality operators" do
    test "EQUAL_TO matches equal values" do
      assert VMO.value_matches?(10, :EQUAL_TO, 10)
      assert VMO.value_matches?("foo", :EQUAL_TO, "foo")
    end

    test "EQUAL_TO does not match different values" do
      refute VMO.value_matches?(10, :EQUAL_TO, 20)
    end

    test "NOT_EQUAL_TO matches different values" do
      assert VMO.value_matches?(10, :NOT_EQUAL_TO, 20)
    end

    test "NOT_EQUAL_TO does not match equal values" do
      refute VMO.value_matches?(10, :NOT_EQUAL_TO, 10)
    end
  end

  describe "comparison operators" do
    test "GREATER_THAN" do
      assert VMO.value_matches?(10, :GREATER_THAN, 5)
      refute VMO.value_matches?(5, :GREATER_THAN, 10)
    end

    test "GREATER_OR_EQUAL_TO" do
      assert VMO.value_matches?(10, :GREATER_OR_EQUAL_TO, 10)
      assert VMO.value_matches?(11, :GREATER_OR_EQUAL_TO, 10)
      refute VMO.value_matches?(9, :GREATER_OR_EQUAL_TO, 10)
    end

    test "LESS_THAN" do
      assert VMO.value_matches?(5, :LESS_THAN, 10)
      refute VMO.value_matches?(10, :LESS_THAN, 5)
    end

    test "LESS_OR_EQUAL_TO" do
      assert VMO.value_matches?(10, :LESS_OR_EQUAL_TO, 10)
      assert VMO.value_matches?(9, :LESS_OR_EQUAL_TO, 10)
      refute VMO.value_matches?(11, :LESS_OR_EQUAL_TO, 10)
    end
  end

  describe "CONTAINS operator" do
    test "matches when binary contains substring" do
      assert VMO.value_matches?("hello world", :CONTAINS, "world")
    end

    test "does not match when binary does not contain substring" do
      refute VMO.value_matches?("hello", :CONTAINS, "world")
    end

    test "matches when list contains element" do
      assert VMO.value_matches?([1, 2, 3], :CONTAINS, 2)
    end

    test "does not match when list does not contain element" do
      refute VMO.value_matches?([1, 2, 3], :CONTAINS, 4)
    end

    test "returns false for unsupported received_value types" do
      refute VMO.value_matches?(123, :CONTAINS, 2)
      refute VMO.value_matches?(%{}, :CONTAINS, :a)
    end
  end

  describe "NOT_CONTAINS operator" do
    test "matches when binary does not contain substring" do
      assert VMO.value_matches?("hello", :NOT_CONTAINS, "world")
    end

    test "does not match when binary contains substring" do
      refute VMO.value_matches?("hello world", :NOT_CONTAINS, "world")
    end

    test "matches when list does not contain element" do
      assert VMO.value_matches?([1, 2, 3], :NOT_CONTAINS, 4)
    end

    test "does not match when list contains element" do
      refute VMO.value_matches?([1, 2, 3], :NOT_CONTAINS, 2)
    end

    test "returns false for unsupported received_value types" do
      refute VMO.value_matches?(123, :NOT_CONTAINS, 2)
      refute VMO.value_matches?(%{}, :NOT_CONTAINS, :a)
    end
  end
end
