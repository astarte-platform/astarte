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
             DateTime.from_unix!(1_527_004_491_000, :millisecond)

    datetime_millis = 1_527_004_491 * 1000

    assert AstarteValue.to_json_friendly(datetime_millis, :datetime, keep_milliseconds: true) ==
             datetime_millis

    datetime_millis = 1_527_004_491 * 1000

    assert AstarteValue.to_json_friendly([datetime_millis], :datetimearray, []) ==
             [DateTime.from_unix!(1_527_004_491_000, :millisecond)]

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
