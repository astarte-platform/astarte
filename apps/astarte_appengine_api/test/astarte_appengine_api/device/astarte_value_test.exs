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

defmodule Astarte.AppEngine.API.AstarteValueTest do
  use ExUnit.Case
  alias Astarte.AppEngine.API.Device.AstarteValue

  test "binary blobs to json friendly" do
    assert AstarteValue.to_json_friendly(<<0, 1, 3, 4>>, :binaryblob, []) == "AAEDBA=="

    assert AstarteValue.to_json_friendly([<<0, 1, 3, 4>>, <<5>>], :binaryblobarray, []) == [
             "AAEDBA==",
             "BQ=="
           ]
  end

  test "longintegers to json friendly" do
    biggest_u64 = 0xFFFFFFFFFFFFFFFF
    biggest_uint64_string = "18446744073709551615"
    assert AstarteValue.to_json_friendly(biggest_u64, :longinteger, []) == biggest_uint64_string

    assert AstarteValue.to_json_friendly(biggest_u64, :longinteger, allow_safe_bigintegers: true) ==
             biggest_uint64_string

    assert AstarteValue.to_json_friendly(42, :longinteger, []) == "42"
    assert AstarteValue.to_json_friendly(42, :longinteger, allow_safe_bigintegers: true) == 42

    assert AstarteValue.to_json_friendly([1, 2], :longintegerarray, []) == ["1", "2"]

    assert AstarteValue.to_json_friendly([1, 2], :longintegerarray, allow_safe_bigintegers: true) ==
             [1, 2]
  end

  test "datetime to json friendly" do
    datetime_millis = 1_527_004_491 * 1000

    assert AstarteValue.to_json_friendly(datetime_millis, :datetime, []) ==
             DateTime.from_unix!(1_527_004_491_000, :milliseconds)

    datetime_millis = 1_527_004_491 * 1000

    assert AstarteValue.to_json_friendly(datetime_millis, :datetime, keep_milliseconds: true) ==
             datetime_millis

    datetime_millis = 1_527_004_491 * 1000

    assert AstarteValue.to_json_friendly([datetime_millis], :datetimearray, []) ==
             [DateTime.from_unix!(1_527_004_491_000, :milliseconds)]

    datetime_millis = 1_527_004_491 * 1000

    assert AstarteValue.to_json_friendly(
             [datetime_millis],
             :datetimearray,
             keep_milliseconds: true
           ) == [datetime_millis]
  end

  test "any other type to json friendly" do
    assert AstarteValue.to_json_friendly("hello", :string, []) == "hello"

    assert AstarteValue.to_json_friendly(["hello", "world"], :stringarray, []) == [
             "hello",
             "world"
           ]

    assert AstarteValue.to_json_friendly(0, :integer, []) == 0
    assert AstarteValue.to_json_friendly(true, :boolean, []) == true
  end

  test "json friendly fails on unsupported argument" do
    assert_raise ArgumentError, fn ->
      assert AstarteValue.to_json_friendly(:null, :string, [])
    end

    assert_raise ArgumentError, fn ->
      assert AstarteValue.to_json_friendly(nil, :string, [])
    end
  end
end
