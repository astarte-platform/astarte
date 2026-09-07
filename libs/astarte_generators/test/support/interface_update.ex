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

defmodule Astarte.Core.Generators.InterfaceUpdateTest.Support do
  @moduledoc false

  import Astarte.Core.Generators.Mapping.Value, only: [path_matches_endpoint?: 3]
  import Astarte.Core.Mapping.ValueType, only: [validate_value: 2]

  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping

  @spec valid_update?(
          Interface.t(),
          Astarte.Core.Generators.InterfaceUpdate.t(),
          Astarte.Core.Generators.InterfaceUpdate.representation_t()
        ) :: boolean()
  def valid_update?(
        %Interface{aggregation: :individual, mappings: mappings, type: interface_type},
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
        path_matches_endpoint?(:individual, endpoint, path)
      end)

    Enum.all?([
      value_type == mapping_value_type,
      reliability == expected_reliability(interface_type, mapping_reliability),
      represented?(value_type, value, representation)
    ])
  end

  def valid_update?(
        %Interface{aggregation: :object, mappings: mappings, type: interface_type},
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
        path_matches_endpoint?(:object, endpoint, path)
      end)

    type_keys = value_type |> Map.keys() |> MapSet.new()
    value_keys = value |> Map.keys() |> MapSet.new()

    Enum.all?([
      path_matches,
      reliability == expected_reliability(interface_type, mapping_reliability),
      type_keys == value_keys,
      Enum.all?(value_type, fn {key, type} ->
        represented?(type, Map.fetch!(value, key), representation)
      end)
    ])
  end

  @spec represented?(
          atom(),
          any(),
          Astarte.Core.Generators.InterfaceUpdate.representation_t()
        ) :: boolean()
  def represented?(:binaryblob, value, :api),
    do: match?({:ok, _value}, Base.decode64(value))

  def represented?(:datetime, value, :api) when is_integer(value), do: true

  def represented?(:datetime, value, :api),
    do: match?({:ok, _datetime, _offset}, DateTime.from_iso8601(value))

  def represented?(:binaryblob, %Cyanide.Binary{}, :database), do: true
  def represented?(:datetime, value, :database) when is_integer(value), do: true
  def represented?(:datetime, %DateTime{}, :database), do: true

  def represented?(type, values, representation) when is_list(values),
    do: Enum.all?(values, &represented?(array_type(type), &1, representation))

  def represented?(type, value, _representation), do: validate_value(type, value) == :ok

  defp expected_reliability(:properties, _mapping_reliability), do: :unique
  defp expected_reliability(:datastream, mapping_reliability), do: mapping_reliability

  defp array_type(:doublearray), do: :double
  defp array_type(:integerarray), do: :integer
  defp array_type(:longintegerarray), do: :longinteger
  defp array_type(:booleanarray), do: :boolean
  defp array_type(:stringarray), do: :string
  defp array_type(:binaryblobarray), do: :binaryblob
  defp array_type(:datetimearray), do: :datetime
end
