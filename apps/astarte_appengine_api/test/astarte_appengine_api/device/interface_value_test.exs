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

defmodule Astarte.AppEngine.API.InterfaceValueTest do
  use ExUnit.Case
  alias Astarte.AppEngine.API.Device.InterfaceValue

  test "cast datetime values with valid data" do
    assert InterfaceValue.cast_value(:datetime, "2024-06-20T14:02:05.371Z") ==
             {:ok, ~U[2024-06-20 14:02:05.371Z]}

    assert InterfaceValue.cast_value(:datetimearray, [
             "2024-06-20T14:02:05.371Z",
             "2024-06-20T14:02:05.371Z"
           ]) ==
             {:ok, [~U[2024-06-20 14:02:05.371Z], ~U[2024-06-20 14:02:05.371Z]]}
  end

  test "cast binary blob values with valid data" do
    assert InterfaceValue.cast_value(:binaryblob, "AAEDBA==") ==
             {:ok, <<0, 1, 3, 4>>}

    assert InterfaceValue.cast_value(:binaryblobarray, ["AAEDBA==", "BQ=="]) ==
             {:ok, [<<0, 1, 3, 4>>, <<5>>]}
  end

  test "cast double values with valid data" do
    assert InterfaceValue.cast_value(:double, 12.1) ==
             {:ok, 12.1}

    assert InterfaceValue.cast_value(:doublearray, [12.1, 13.2]) ==
             {:ok, [12.1, 13.2]}
  end

  test "cast long integer values with valid data" do
    # Cast long integer when value is represented as a valid string
    assert InterfaceValue.cast_value(:longinteger, "9223372036854775807") ==
             {:ok, 9_223_372_036_854_775_807}

    # Cast long integer when value is represented as a valid integer
    assert InterfaceValue.cast_value(:longinteger, 123) ==
             {:ok, 123}

    # Cast long integer when value is represented as an array of valid strings
    assert InterfaceValue.cast_value(:longintegerarray, [
             "9223372036854775806",
             "9223372036854775807"
           ]) ==
             {:ok, [9_223_372_036_854_775_806, 9_223_372_036_854_775_807]}

    # Cast long integer when value is represented as an array of valid integers
    assert InterfaceValue.cast_value(:longintegerarray, [
             123,
             456
           ]) ==
             {:ok, [123, 456]}
  end

  test "cast any other type with valid data" do
    assert InterfaceValue.cast_value(:string, "stringvalue") ==
             {:ok, "stringvalue"}

    assert InterfaceValue.cast_value(:stringarray, ["stringvalue1", "stringvalue2"]) ==
             {:ok, ["stringvalue1", "stringvalue2"]}

    assert InterfaceValue.cast_value(:integer, 123) ==
             {:ok, 123}

    assert InterfaceValue.cast_value(:integerarray, [123, 456]) ==
             {:ok, [123, 456]}

    assert InterfaceValue.cast_value(:boolean, true) ==
             {:ok, true}

    assert InterfaceValue.cast_value(:booleanarray, [true, false]) ==
             {:ok, [true, false]}
  end

  test "cast datetime values with invalid data" do
    assert InterfaceValue.cast_value(:datetime, "2024-06-20") ==
             {:error, :unexpected_value_type, [expected: :datetime]}

    assert InterfaceValue.cast_value(:datetimearray, [
             "2024-06-20",
             "2024-06-21"
           ]) ==
             {:error, :unexpected_value_type, [expected: :datetimearray]}
  end

  test "cast binary blob values with invalid data" do
    assert InterfaceValue.cast_value(:binaryblob, "AAE") ==
             {:error, :unexpected_value_type, [expected: :binaryblob]}

    assert InterfaceValue.cast_value(:binaryblobarray, ["AAE", "BQ"]) ==
             {:error, :unexpected_value_type, [expected: :binaryblobarray]}
  end

  test "cast double values with invalid data" do
    assert InterfaceValue.cast_value(:double, "123.1") ==
             {:error, :unexpected_value_type, [expected: :double]}

    assert InterfaceValue.cast_value(:doublearray, ["123.1"]) ==
             {:error, :unexpected_value_type, [expected: :doublearray]}
  end

  test "cast long integer values with invalid data" do
    assert InterfaceValue.cast_value(:longinteger, "invalid_data") ==
             {:error, :unexpected_value_type, [expected: :longinteger]}

    assert InterfaceValue.cast_value(:longintegerarray, [
             "invalid_data"
           ]) ==
             {:error, :unexpected_value_type, [expected: :longintegerarray]}
  end

  test "cast object values correctly when types match" do
    expected_types = %{
      "a" => :integer,
      "b" => :string
    }

    object = %{
      "a" => 123,
      "b" => "hello"
    }

    assert InterfaceValue.cast_value(expected_types, object) ==
             {:ok, %{"a" => 123, "b" => "hello"}}
  end

  test "returns error when object key is not in expected types" do
    expected_types = %{
      "a" => :integer,
      "b" => :string
    }

    object = %{
      "a" => 123,
      "b" => "hello",
      "c" => "unexpected"
    }

    assert InterfaceValue.cast_value(expected_types, object) == {:error, :unexpected_object_key}
  end

  test "returns error when value type does not match expected type" do
    expected_types = %{
      "a" => :longinteger,
      "b" => :string
    }

    object = %{
      "a" => "not long integer",
      "b" => "hello"
    }

    assert InterfaceValue.cast_value(expected_types, object) ==
             {:error, :unexpected_value_type, [expected: :longinteger]}
  end
end
