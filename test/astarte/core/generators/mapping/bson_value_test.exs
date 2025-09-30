#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Core.Generators.Mapping.BSONValueTest do
  @moduledoc """
  Tests for Astarte Mapping BSONValueTest
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Mapping.ValueType

  alias Astarte.Core.Generators.Mapping.BSONValue, as: BSONValueGenerator
  alias Astarte.Core.Generators.Mapping.ValueType, as: ValueTypeGenerator

  @moduletag :core
  @moduletag :mapping
  @moduletag :bson_value

  @wrapped_type [:binaryblob, :binaryblobarray]
  @not_wrapped_type ValueTypeGenerator.valid_atoms() -- @wrapped_type

  defp normalize_value(value, :datetime), do: DateTime.truncate(value, :millisecond)

  defp normalize_value(value, :datetimearray),
    do: Enum.map(value, &normalize_value(&1, :datetime))

  defp normalize_value(value, _), do: value

  defp gen_values(type) when is_atom(type), do: gen_values([type])

  defp gen_values(types) when is_list(types) do
    gen all type <- member_of(types),
            value <- ValueTypeGenerator.value_from_type(type),
            value = normalize_value(value, type),
            bson_value <- BSONValueGenerator.to_bson_value(value, type) do
      {value, bson_value}
    end
  end

  @doc false
  describe "bson_value generator" do
    @describetag :success
    @describetag :ut

    property "validate data passing type" do
      check all type <- member_of(@not_wrapped_type),
                bson_value <- BSONValueGenerator.bson_value(type) do
        refute is_nil(Cyanide.decode!(bson_value))
      end
    end

    property "validate passed value (not wrapped) using struct" do
      check all {value, bson_value} <- gen_values(@not_wrapped_type) do
        assert %{"v" => ^value} = Cyanide.decode!(bson_value)
      end
    end

    property "validate passed value (not wrapped) using gen" do
      check all type <- member_of(@not_wrapped_type),
                bson_value <-
                  ValueTypeGenerator.value_from_type(type)
                  |> map(&normalize_value(&1, type))
                  |> BSONValueGenerator.to_bson_value(type) do
        value = Map.get(Cyanide.decode!(bson_value), "v")
        assert :ok = ValueType.validate_value(type, value)
      end
    end

    property "validate encoded :binaryblob" do
      check all {value, bson_value} <- gen_values(:binaryblob) do
        assert %{"v" => %Cyanide.Binary{subtype: :generic, data: ^value}} =
                 Cyanide.decode!(bson_value)
      end
    end

    property "validate encoded :binaryblobarray" do
      check all {values, bson_values} <- gen_values(:binaryblobarray) do
        decoded_values = Map.fetch!(Cyanide.decode!(bson_values), "v")

        for {value, bson_value} <- Enum.zip(values, decoded_values) do
          assert %Cyanide.Binary{subtype: :generic, data: ^value} = bson_value
        end
      end
    end
  end
end
