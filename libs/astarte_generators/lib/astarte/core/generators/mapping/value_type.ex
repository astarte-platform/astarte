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

defmodule Astarte.Core.Generators.Mapping.ValueType do
  @moduledoc """
  This module provides generators for any ValueType.
  """
  use ExUnitProperties

  alias Astarte.Core.Mapping.ValueType

  alias Astarte.Common.Generators.DateTime, as: DateTimeGenerator

  @valid_atoms [
    :double,
    :integer,
    :boolean,
    :longinteger,
    :string,
    :binaryblob,
    :datetime,
    :doublearray,
    :integerarray,
    :booleanarray,
    :longintegerarray,
    :stringarray,
    :binaryblobarray,
    :datetimearray
  ]

  @type valid_t ::
          unquote(
            @valid_atoms
            |> Enum.map_join(" | ", &inspect/1)
            |> Code.string_to_quoted!()
          )

  @doc """
  List of all astarte's ValueType atoms
  """
  @spec valid_atoms() :: list(atom())
  def valid_atoms, do: @valid_atoms

  @doc """
  Generates a valid ValueType
  """
  @spec value_type() :: StreamData.t(ValueType.t())
  def value_type, do: member_of(valid_atoms())

  @doc """
  Generates a valid value from ValueType
  """
  @spec value_from_type(type :: valid_t()) :: StreamData.t(any())
  def value_from_type(:double), do: float()
  def value_from_type(:integer), do: integer(-0x7FFFFFFF..0x7FFFFFFF)
  def value_from_type(:boolean), do: boolean()
  def value_from_type(:longinteger), do: integer(-0x7FFFFFFFFFFFFFFF..0x7FFFFFFFFFFFFFFF)
  def value_from_type(:string), do: string(:utf8, max_length: 65_535)
  def value_from_type(:binaryblob), do: binary(max_length: 65_535)

  def value_from_type(:datetime), do: DateTimeGenerator.date_time()

  def value_from_type(array) when is_atom(array),
    do: type_array(array) |> value_from_type() |> list_of(max_length: 1023)

  defp type_array(:doublearray), do: :double
  defp type_array(:integerarray), do: :integer
  defp type_array(:longintegerarray), do: :longinteger
  defp type_array(:booleanarray), do: :boolean
  defp type_array(:stringarray), do: :string
  defp type_array(:binaryblobarray), do: :binaryblob
  defp type_array(:datetimearray), do: :datetime
end
