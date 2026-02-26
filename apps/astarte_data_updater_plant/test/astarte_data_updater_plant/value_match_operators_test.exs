#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.DataUpdaterPlant.ValueMatchOperatorsTest do
  alias Astarte.DataUpdaterPlant.ValueMatchOperators
  use ExUnit.Case, async: true

  test "any match operator matches everything" do
    assert ValueMatchOperators.value_matches?(5, :ANY, nil) == true
    assert ValueMatchOperators.value_matches?(nil, :ANY, nil) == true
    assert ValueMatchOperators.value_matches?(true, :ANY, false) == true
    assert ValueMatchOperators.value_matches?(0, :ANY, 0) == true
    assert ValueMatchOperators.value_matches?(1, :ANY, 0) == true

    assert ValueMatchOperators.value_matches?("test", :ANY, nil) == true
  end

  test "greater than operator" do
    assert ValueMatchOperators.value_matches?(6, :GREATER_THAN, 5) == true
    assert ValueMatchOperators.value_matches?(6.1, :GREATER_THAN, 6) == true
    assert ValueMatchOperators.value_matches?(6, :GREATER_THAN, 6) == false
    assert ValueMatchOperators.value_matches?(5, :GREATER_THAN, 6) == false
    assert ValueMatchOperators.value_matches?(5, :GREATER_THAN, nil) == false
    assert ValueMatchOperators.value_matches?(nil, :GREATER_THAN, 5) == false

    # Lexical ordering
    assert ValueMatchOperators.value_matches?("test", :GREATER_THAN, "test") == false
    assert ValueMatchOperators.value_matches?("hello", :GREATER_THAN, "world") == false
    assert ValueMatchOperators.value_matches?("z", :GREATER_THAN, "a") == true
    assert ValueMatchOperators.value_matches?(nil, :GREATER_THAN, "a") == false

    # Booleans ordering
    assert ValueMatchOperators.value_matches?(true, :GREATER_THAN, true) == false
    assert ValueMatchOperators.value_matches?(false, :GREATER_THAN, false) == false
    assert ValueMatchOperators.value_matches?(true, :GREATER_THAN, false) == true
    assert ValueMatchOperators.value_matches?(false, :GREATER_THAN, true) == false
  end

  test "greater than or equal to operator" do
    assert ValueMatchOperators.value_matches?(6, :GREATER_OR_EQUAL_TO, 5) == true
    assert ValueMatchOperators.value_matches?(6, :GREATER_OR_EQUAL_TO, 6) == true
    assert ValueMatchOperators.value_matches?(6.1, :GREATER_OR_EQUAL_TO, 6) == true
    assert ValueMatchOperators.value_matches?(5, :GREATER_OR_EQUAL_TO, 6) == false
    assert ValueMatchOperators.value_matches?(5, :GREATER_OR_EQUAL_TO, nil) == false
    assert ValueMatchOperators.value_matches?(nil, :GREATER_OR_EQUAL_TO, 5) == false

    # Lexical ordering
    assert ValueMatchOperators.value_matches?("test", :GREATER_OR_EQUAL_TO, "test") == true
    assert ValueMatchOperators.value_matches?("hello", :GREATER_OR_EQUAL_TO, "world") == false
    assert ValueMatchOperators.value_matches?("z", :GREATER_OR_EQUAL_TO, "a") == true
    assert ValueMatchOperators.value_matches?(nil, :GREATER_OR_EQUAL_TO, "a") == false

    # Booleans ordering
    assert ValueMatchOperators.value_matches?(true, :GREATER_OR_EQUAL_TO, true) == true
    assert ValueMatchOperators.value_matches?(false, :GREATER_OR_EQUAL_TO, false) == true
    assert ValueMatchOperators.value_matches?(true, :GREATER_OR_EQUAL_TO, false) == true
    assert ValueMatchOperators.value_matches?(false, :GREATER_OR_EQUAL_TO, true) == false
  end

  test "less than operator" do
    assert ValueMatchOperators.value_matches?(6, :LESS_THAN, 5) == false
    assert ValueMatchOperators.value_matches?(6.1, :LESS_THAN, 6) == false
    assert ValueMatchOperators.value_matches?(6, :LESS_THAN, 6) == false
    assert ValueMatchOperators.value_matches?(5, :LESS_THAN, 6) == true
    assert ValueMatchOperators.value_matches?(5, :LESS_THAN, 5.1) == true
    assert ValueMatchOperators.value_matches?(nil, :LESS_THAN, 5) == false

    # Lexical ordering
    assert ValueMatchOperators.value_matches?("test", :LESS_THAN, "test") == false
    assert ValueMatchOperators.value_matches?("hello", :LESS_THAN, "world") == true
    assert ValueMatchOperators.value_matches?("z", :LESS_THAN, "a") == false
    assert ValueMatchOperators.value_matches?(nil, :LESS_THAN, "a") == false

    # Booleans ordering
    assert ValueMatchOperators.value_matches?(true, :LESS_THAN, true) == false
    assert ValueMatchOperators.value_matches?(false, :LESS_THAN, false) == false
    assert ValueMatchOperators.value_matches?(true, :LESS_THAN, false) == false
    assert ValueMatchOperators.value_matches?(false, :LESS_THAN, true) == true
  end

  test "less than or equal to operator" do
    assert ValueMatchOperators.value_matches?(6, :LESS_OR_EQUAL_TO, 5) == false
    assert ValueMatchOperators.value_matches?(6, :LESS_OR_EQUAL_TO, 6) == true
    assert ValueMatchOperators.value_matches?(6.1, :LESS_OR_EQUAL_TO, 6) == false
    assert ValueMatchOperators.value_matches?(5, :LESS_OR_EQUAL_TO, 6) == true
    assert ValueMatchOperators.value_matches?(6, :LESS_OR_EQUAL_TO, 6.1) == true
    assert ValueMatchOperators.value_matches?(nil, :LESS_OR_EQUAL_TO, 5) == false

    # Lexical ordering
    assert ValueMatchOperators.value_matches?("test", :LESS_OR_EQUAL_TO, "test") == true
    assert ValueMatchOperators.value_matches?("hello", :LESS_OR_EQUAL_TO, "world") == true
    assert ValueMatchOperators.value_matches?("z", :LESS_OR_EQUAL_TO, "a") == false
    assert ValueMatchOperators.value_matches?(nil, :LESS_OR_EQUAL_TO, "a") == false

    # Booleans ordering
    assert ValueMatchOperators.value_matches?(true, :LESS_OR_EQUAL_TO, true) == true
    assert ValueMatchOperators.value_matches?(false, :LESS_OR_EQUAL_TO, false) == true
    assert ValueMatchOperators.value_matches?(true, :LESS_OR_EQUAL_TO, false) == false
    assert ValueMatchOperators.value_matches?(false, :LESS_OR_EQUAL_TO, true) == true
  end

  test "equal to operator" do
    assert ValueMatchOperators.value_matches?(6, :EQUAL_TO, 5) == false
    assert ValueMatchOperators.value_matches?(6.1, :EQUAL_TO, 6) == false
    assert ValueMatchOperators.value_matches?(6, :EQUAL_TO, 6) == true
    assert ValueMatchOperators.value_matches?(5, :EQUAL_TO, 6) == false
    assert ValueMatchOperators.value_matches?(5, :EQUAL_TO, 5.1) == false
    assert ValueMatchOperators.value_matches?(5, :EQUAL_TO, nil) == false
    assert ValueMatchOperators.value_matches?(nil, :EQUAL_TO, 5) == false
    assert ValueMatchOperators.value_matches?(6.0, :EQUAL_TO, 6) == true

    # known_value nil doesn't matter for any operator different than any

    assert ValueMatchOperators.value_matches?("test", :EQUAL_TO, "test") == true
    assert ValueMatchOperators.value_matches?("hello", :EQUAL_TO, "world") == false

    assert ValueMatchOperators.value_matches?(true, :EQUAL_TO, true) == true
    assert ValueMatchOperators.value_matches?(true, :EQUAL_TO, false) == false
  end

  test "not equal to operator" do
    assert ValueMatchOperators.value_matches?(6, :NOT_EQUAL_TO, 5) == true
    assert ValueMatchOperators.value_matches?(6, :NOT_EQUAL_TO, 6) == false
    assert ValueMatchOperators.value_matches?(6.1, :NOT_EQUAL_TO, 6) == true
    assert ValueMatchOperators.value_matches?(6.0, :NOT_EQUAL_TO, 6) == false
    assert ValueMatchOperators.value_matches?(5, :NOT_EQUAL_TO, 6) == true
    assert ValueMatchOperators.value_matches?(6, :NOT_EQUAL_TO, 6.1) == true
    # Beware, value_matches? returns if the value matches,
    # so false is a valid answer for "does nil NOT_EQUAL_TO 5 matches 5"
    assert ValueMatchOperators.value_matches?(nil, :NOT_EQUAL_TO, 5) == false

    # known_value nil doesn't matter for any operator different than any

    assert ValueMatchOperators.value_matches?("test", :NOT_EQUAL_TO, "test") == false
    assert ValueMatchOperators.value_matches?("hello", :NOT_EQUAL_TO, "world") == true

    assert ValueMatchOperators.value_matches?(true, :NOT_EQUAL_TO, true) == false
    assert ValueMatchOperators.value_matches?(true, :NOT_EQUAL_TO, false) == true
  end

  test "contains match operator" do
    # String contains
    assert ValueMatchOperators.value_matches?("Hello World", :CONTAINS, "World") == true
    assert ValueMatchOperators.value_matches?("Hello World", :CONTAINS, "Mondo") == false
    assert ValueMatchOperators.value_matches?(5, :CONTAINS, 0) == false
    assert ValueMatchOperators.value_matches?(nil, :CONTAINS, "World") == false

    assert ValueMatchOperators.value_matches?([1, 2, 3], :CONTAINS, 2) == true
    assert ValueMatchOperators.value_matches?([1, 2, 3], :CONTAINS, 5) == false
  end

  test "not contains match operator" do
    assert ValueMatchOperators.value_matches?("Hello World", :NOT_CONTAINS, "World") == false
    assert ValueMatchOperators.value_matches?("Hello World", :NOT_CONTAINS, "Mondo") == true
    assert ValueMatchOperators.value_matches?(5, :NOT_CONTAINS, 0) == false
    assert ValueMatchOperators.value_matches?(nil, :NOT_CONTAINS, "World") == false

    assert ValueMatchOperators.value_matches?([1, 2, 3], :NOT_CONTAINS, 2) == false
    assert ValueMatchOperators.value_matches?([1, 2, 3], :NOT_CONTAINS, 5) == true
  end
end
