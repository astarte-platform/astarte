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

defmodule Astarte.Core.Generators.InterfaceUpdateTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Interface
  import Astarte.Core.Generators.InterfaceUpdate
  import Astarte.Core.Generators.Mapping.ValueType, only: [value_type: 0]
  import Astarte.Core.Mapping.ValueType, only: [validate_value: 2]

  alias Astarte.Core.Generators.Mapping.Value, as: ValueGenerator
  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping

  describe "interface update generator" do
    property "generates represented updates for individual interfaces" do
      check all interface <- interface(aggregation: :individual),
                api_update <- valid_mapping_update_for(interface, :api),
                database_update <- valid_mapping_update_for(interface, :database) do
        assert valid_individual_update?(interface, api_update, :api) and
                 valid_individual_update?(interface, database_update, :database)
      end
    end

    property "generates represented updates for object interfaces" do
      check all interface <- interface(aggregation: :object),
                api_update <- valid_mapping_update_for(interface, :api),
                database_update <- valid_mapping_update_for(interface, :database) do
        assert valid_object_update?(interface, api_update, :api) and
                 valid_object_update?(interface, database_update, :database)
      end
    end

    property "generates standalone represented individual and object values" do
      check all value_type <- value_type(),
                api_value <- valid_update_value_for(value_type, :api),
                database_value <- valid_update_value_for(%{"value" => value_type}, :database) do
        assert represented?(value_type, api_value, :api) and
                 represented?(value_type, Map.fetch!(database_value, "value"), :database)
      end
    end

    test "force_allow_unset permits an empty database value" do
      interface = %Interface{
        aggregation: :individual,
        type: :properties,
        mappings: [
          %Mapping{endpoint: "/value", reliability: :unreliable, value_type: :string}
        ]
      }

      assert %{
               aggregation: :individual,
               reliability: :unique,
               value: "",
               value_type: :string
             } =
               interface
               |> valid_mapping_update_for(:database, force_allow_unset: true)
               |> StreamData.resize(0)
               |> Enum.at(0)
    end
  end

  defp valid_individual_update?(
         %Interface{mappings: mappings, type: interface_type},
         %{
           aggregation: :individual,
           path: path,
           reliability: reliability,
           value: value,
           value_type: value_type
         },
         representation
       ) do
    %Mapping{reliability: mapping_reliability, value_type: mapping_value_type} =
      Enum.find(mappings, fn %Mapping{endpoint: endpoint} ->
        ValueGenerator.path_matches_endpoint?(:individual, endpoint, path)
      end)

    value_type == mapping_value_type and
      reliability == expected_reliability(interface_type, mapping_reliability) and
      represented?(value_type, value, representation)
  end

  defp valid_object_update?(
         %Interface{mappings: mappings, type: interface_type},
         %{
           aggregation: :object,
           path: path,
           reliability: reliability,
           value: value,
           value_type: value_type
         },
         representation
       ) do
    %Mapping{reliability: mapping_reliability} = List.first(mappings)

    path_matches =
      Enum.any?(mappings, fn %Mapping{endpoint: endpoint} ->
        ValueGenerator.path_matches_endpoint?(:object, endpoint, path)
      end)

    type_keys = value_type |> Map.keys() |> MapSet.new()
    value_keys = value |> Map.keys() |> MapSet.new()

    path_matches and
      reliability == expected_reliability(interface_type, mapping_reliability) and
      type_keys == value_keys and
      Enum.all?(value_type, fn {key, type} ->
        represented?(type, Map.fetch!(value, key), representation)
      end)
  end

  defp expected_reliability(:properties, _mapping_reliability), do: :unique
  defp expected_reliability(:datastream, mapping_reliability), do: mapping_reliability

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
