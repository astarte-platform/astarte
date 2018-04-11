#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.DataUpdaterPlant.ValueMatchOperatorsTest do
  alias Astarte.DataUpdaterPlant.ValueMatchOperators
  use ExUnit.Case

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
end
