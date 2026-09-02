#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Astarte.Core.Generators.Mapping.ValueTypeTest do
  @moduledoc """
  Tests for Astarte Mapping ValueTypeTest
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Mapping.ValueType
  import Astarte.Core.Mapping.ValueType, only: [cast: 1, validate_value: 2]

  @moduletag :core
  @moduletag :mapping
  @moduletag :value_type

  defp valid_cast(type) when is_atom(type) do
    case cast(type) do
      {:ok, _} -> true
      :error -> false
    end
  end

  @doc false
  describe "value_type generator" do
    @describetag :success
    @describetag :ut

    test "validate all valid_atoms in value_type generator",
      do: assert(value_type_valid_atoms() |> Enum.all?(&valid_cast/1))

    property "validate generated value_type using validate_value/2" do
      check all value_type <- value_type() do
        assert valid_cast(value_type)
      end
    end

    property "validate generated value_type using value_from_type/1" do
      check all value_type <- value_type(),
                value <- value_from_type(value_type) do
        assert validate_value(value_type, value)
      end
    end

    property "generates API and database value representations" do
      check all value_type <- value_type(),
                api_value <- value_from_type(value_type, representation: :api),
                database_value <- value_from_type(value_type, representation: :database) do
        assert represented?(value_type, api_value, :api) and
                 represented?(value_type, database_value, :database)
      end
    end

    test "force_allow_unset permits empty database values" do
      assert {"", []} ==
               {
                 value_from_type(:string,
                   representation: :database,
                   force_allow_unset: true
                 )
                 |> StreamData.resize(0)
                 |> Enum.at(0),
                 value_from_type(:stringarray,
                   representation: :database,
                   force_allow_unset: true
                 )
                 |> StreamData.resize(0)
                 |> Enum.at(0)
               }
    end
  end

  defp represented?(:binaryblob, value, :api), do: match?({:ok, _value}, Base.decode64(value))

  defp represented?(:datetime, value, :api) when is_integer(value), do: true

  defp represented?(:datetime, value, :api),
    do: match?({:ok, _datetime, _offset}, DateTime.from_iso8601(value))

  defp represented?(:binaryblob, %Cyanide.Binary{}, :database), do: true
  defp represented?(:datetime, value, :database) when is_integer(value), do: true
  defp represented?(:datetime, %DateTime{}, :database), do: true

  defp represented?(type, values, representation) when is_list(values),
    do: Enum.all?(values, &represented?(array_type(type), &1, representation))

  defp represented?(type, value, _representation), do: validate_value(type, value) == :ok

  defp array_type(:doublearray), do: :double
  defp array_type(:integerarray), do: :integer
  defp array_type(:longintegerarray), do: :longinteger
  defp array_type(:booleanarray), do: :boolean
  defp array_type(:stringarray), do: :string
  defp array_type(:binaryblobarray), do: :binaryblob
  defp array_type(:datetimearray), do: :datetime
end
