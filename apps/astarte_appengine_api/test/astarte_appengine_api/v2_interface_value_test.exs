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

defmodule Astarte.AppEngine.API.V2InterfaceValueTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.AppEngine.API.Device.InterfaceValue
  alias Astarte.Test.Generators.Common, as: CommonGenerator
  alias Astarte.Test.Generators.DateTime, as: DateTimeGenerator
  alias Astarte.Test.Generators.Number, as: NumberGenerator
  alias Astarte.Test.Generators.String, as: StringGenerator

  @max_safe_integer 9_007_199_254_740_991

  property "Valid Datetime values are correctly casted" do
    check all generated_datetime <- DateTimeGenerator.date_time!() do
      valid_datetime =
        generated_datetime
        |> Map.update!(:microsecond, fn {us, _} -> {us, 3} end)

      parsed_datetime = DateTime.to_iso8601(valid_datetime, :extended)

      assert InterfaceValue.cast_value(:datetime, parsed_datetime) ==
               {:ok, valid_datetime}
    end
  end

  property "Valid Datetime array values are correctly casted" do
    check all generated_datetimes <- list_of(DateTimeGenerator.date_time!(), min_length: 1) do
      valid_datetimes =
        Enum.map(generated_datetimes, fn datetime ->
          Map.update!(datetime, :microsecond, fn {us, _} -> {us, 3} end)
        end)

      parsed_datetimes = Enum.map(valid_datetimes, &DateTime.to_iso8601(&1, :extended))

      assert InterfaceValue.cast_value(:datetimearray, parsed_datetimes) ==
               {:ok, valid_datetimes}
    end
  end

  property "Valid binary blob values are correctly casted" do
    check all blob <- StreamData.binary() do
      base64_blob = Base.encode64(blob)

      assert InterfaceValue.cast_value(:binaryblob, base64_blob) ==
               {:ok, blob}
    end

    check all binary_blob_array <- list_of(StreamData.binary()) do
      valid_binary_blob_array =
        Enum.map(binary_blob_array, fn blob ->
          Base.encode64(blob)
        end)

      parsed_blobs = Enum.map(valid_binary_blob_array, &Base.decode64!/1)

      assert InterfaceValue.cast_value(:binaryblobarray, valid_binary_blob_array) ==
               {:ok, parsed_blobs}
    end
  end

  property "Valid double values are correctly casted" do
    check all number <- StreamData.float() do
      assert InterfaceValue.cast_value(:double, number) ==
               {:ok, number}
    end

    check all double_array <- list_of(StreamData.float()) do
      assert InterfaceValue.cast_value(:doublearray, double_array) ==
               {:ok, double_array}
    end
  end

  property "Valid long integer values are correctly casted" do
    check all integer <- StreamData.integer() do
      assert InterfaceValue.cast_value(:longinteger, integer) ==
               {:ok, integer}

      string_integer = Integer.to_string(integer)

      assert InterfaceValue.cast_value(:longinteger, string_integer) ==
               {:ok, integer}
    end
  end

  property "Valid long integer array values are correctly casted" do
    check all long_integer_array <- NumberGenerator.longinteger_array() do
      parsed_integers =
        Enum.map(long_integer_array, fn
          value when is_integer(value) -> value
          value when is_binary(value) -> String.to_integer(value)
        end)

      assert InterfaceValue.cast_value(:longintegerarray, long_integer_array) ==
               {:ok, parsed_integers}
    end
  end

  property "Other values with valid input are correctly casted" do
    check all string <- StringGenerator.random_string(Enum.random(1..10)) do
      assert InterfaceValue.cast_value(:string, string) ==
               {:ok, string}
    end

    check all string_array <- list_of(StringGenerator.random_string(Enum.random(1..10))) do
      assert InterfaceValue.cast_value(:stringarray, string_array) ==
               {:ok, string_array}
    end

    check all integer <- StreamData.integer() do
      assert InterfaceValue.cast_value(:integer, integer) ==
               {:ok, integer}
    end

    check all integer_array <- NumberGenerator.random_numbers(@max_safe_integer) do
      assert InterfaceValue.cast_value(:integerarray, integer_array) ==
               {:ok, integer_array}
    end

    check all boolean <- StreamData.boolean() do
      assert InterfaceValue.cast_value(:boolean, boolean) ==
               {:ok, boolean}
    end

    check all boolean_array <- list_of(StreamData.boolean()) do
      assert InterfaceValue.cast_value(:booleanarray, boolean_array) ==
               {:ok, boolean_array}
    end
  end

  property "Invalid Datetime values returns :unexpected_value_type error" do
    check all invalid_datetime <- DateTimeGenerator.invalid_datetime() do
      assert InterfaceValue.cast_value(:datetime, invalid_datetime) ==
               {:error, :unexpected_value_type, [expected: :datetime]}
    end

    check all invalid_datetime_array <- DateTimeGenerator.invalid_datetime_array() do
      assert InterfaceValue.cast_value(:datetimearray, invalid_datetime_array) ==
               {:error, :unexpected_value_type, [expected: :datetimearray]}
    end
  end

  property "Invalid binary blob values returns :unexpected_value_type error" do
    check all invalid_blob <-
                CommonGenerator.invalid_binaryblob() do
      assert InterfaceValue.cast_value(:binaryblob, invalid_blob) ==
               {:error, :unexpected_value_type, [expected: :binaryblob]}
    end

    check all invalid_binary_blob_array <-
                CommonGenerator.invalid_binaryblob_array() do
      assert InterfaceValue.cast_value(:binaryblobarray, invalid_binary_blob_array) ==
               {:error, :unexpected_value_type, [expected: :binaryblobarray]}
    end
  end

  property "Invalid double values returns :unexpected_value_type error" do
    check all string <- StreamData.string(:printable) do
      assert InterfaceValue.cast_value(:double, string) ==
               {:error, :unexpected_value_type, [expected: :double]}
    end

    check all invalid_double_array <- list_of(StreamData.string(:printable), min_length: 1) do
      assert InterfaceValue.cast_value(:doublearray, invalid_double_array) ==
               {:error, :unexpected_value_type, [expected: :doublearray]}
    end
  end

  property "Invalid long integer values returns :unexpected_value_type error" do
    check all string <- StreamData.string(:printable, min_length: 1, max_length: 10) do
      assert InterfaceValue.cast_value(:longinteger, string) ==
               {:error, :unexpected_value_type, [expected: :longinteger]}
    end

    check all invalid_longinteger_array <-
                list_of(StreamData.string(:printable), min_length: 1) do
      assert InterfaceValue.cast_value(:longintegerarray, invalid_longinteger_array) ==
               {:error, :unexpected_value_type, [expected: :longintegerarray]}
    end
  end

  property "Valid object values are correctly casted" do
    expected_types = %{
      "a" => :integer,
      "b" => :string
    }

    check all object <- CommonGenerator.object(expected_types) do
      assert InterfaceValue.cast_value(expected_types, object) ==
               {:ok, object}
    end
  end

  property "Object with unexpected object key returns :unexpected_object_key error" do
    expected_types = %{
      "a" => :integer,
      "b" => :string
    }

    check all object <-
                CommonGenerator.object(Map.put(expected_types, "c", :string)) do
      assert InterfaceValue.cast_value(expected_types, object) == {:error, :unexpected_object_key}
    end
  end

  property "Invalid object values returns :unexpected_value_type error" do
    expected_types = %{
      "a" => :longinteger,
      "b" => :string
    }

    check all object <-
                StreamData.fixed_map(%{
                  "a" => StreamData.string(:printable),
                  "b" => StreamData.string(:printable)
                }) do
      assert InterfaceValue.cast_value(expected_types, object) ==
               {:error, :unexpected_value_type, [expected: :longinteger]}
    end
  end
end
