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

defmodule Astarte.AppEngine.API.Device.InterfaceValue do
  def cast_value(expected_types, object) when is_map(expected_types) and is_map(object) do
    Enum.reduce_while(object, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      with {:ok, expected_type} <- Map.fetch(expected_types, key),
           {:ok, normalized_value} <- cast_value(expected_type, value) do
        {:cont, {:ok, Map.put(acc, key, normalized_value)}}
      else
        {:error, reason, expected} ->
          {:halt, {:error, reason, expected}}

        :error ->
          {:halt, {:error, :unexpected_object_key}}
      end
    end)
  end

  def cast_value(:datetime, value) when is_binary(value) do
    with {:ok, datetime, _utc_off} <- DateTime.from_iso8601(value) do
      {:ok, datetime}
    else
      {:error, _reason} ->
        {:error, :unexpected_value_type, expected: :datetime}
    end
  end

  def cast_value(:datetime, value) when is_integer(value) do
    with {:ok, datetime} <- DateTime.from_unix(value, :millisecond) do
      {:ok, datetime}
    else
      {:error, _reason} ->
        {:error, :unexpected_value_type, expected: :datetime}
    end
  end

  def cast_value(:datetime, _value) do
    {:error, :unexpected_value_type, expected: :datetime}
  end

  def cast_value(:binaryblob, value) when is_binary(value) do
    with {:ok, binvalue} <- Base.decode64(value) do
      {:ok, binvalue}
    else
      :error ->
        {:error, :unexpected_value_type, expected: :binaryblob}
    end
  end

  def cast_value(:binaryblob, _value) do
    {:error, :unexpected_value_type, expected: :binaryblob}
  end

  def cast_value(:datetimearray, values) do
    case map_while_ok(values, &cast_value(:datetime, &1)) do
      {:ok, mapped_values} ->
        {:ok, mapped_values}

      _ ->
        {:error, :unexpected_value_type, expected: :datetimearray}
    end
  end

  def cast_value(:binaryblobarray, values) do
    case map_while_ok(values, &cast_value(:binaryblob, &1)) do
      {:ok, mapped_values} ->
        {:ok, mapped_values}

      _ ->
        {:error, :unexpected_value_type, expected: :binaryblobarray}
    end
  end

  # conversion adding 0.0 is required because anyvalue comes from a json value,
  # that does not distinguish from double or int and automatically strip out trailing decimal zeroes
  def cast_value(:double, value) when is_number(value) do
    {:ok, value + 0.0}
  end

  def cast_value(:double, _value) do
    {:error, :unexpected_value_type, expected: :double}
  end

  def cast_value(:doublearray, values) do
    case map_while_ok(values, &cast_value(:double, &1)) do
      {:ok, mapped_values} ->
        {:ok, mapped_values}

      _ ->
        {:error, :unexpected_value_type, expected: :doublearray}
    end
  end

  def cast_value(:longinteger, string_value) when is_binary(string_value) do
    case Integer.parse(string_value) do
      {int_value, ""} ->
        {:ok, int_value}

      _ ->
        {:error, :unexpected_value_type, expected: :longinteger}
    end
  end

  def cast_value(:longinteger, int_value) when is_integer(int_value) do
    {:ok, int_value}
  end

  def cast_value(:longinteger, _value) do
    {:error, :unexpected_value_type, expected: :longinteger}
  end

  def cast_value(:longintegerarray, values) do
    case map_while_ok(values, &cast_value(:longinteger, &1)) do
      {:ok, mapped_values} ->
        {:ok, mapped_values}

      _ ->
        {:error, :unexpected_value_type, expected: :longintegerarray}
    end
  end

  def cast_value(_anytype, anyvalue) do
    {:ok, anyvalue}
  end

  defp map_while_ok(values, fun) when is_list(values) do
    result =
      Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
        case fun.(value) do
          {:ok, mapped_value} ->
            {:cont, {:ok, [mapped_value | acc]}}

          other ->
            {:halt, other}
        end
      end)

    with {:ok, mapped_values} <- result do
      {:ok, Enum.reverse(mapped_values)}
    end
  end

  defp map_while_ok(_not_list_values, _fun) do
    {:error, :values_is_not_a_list}
  end
end
