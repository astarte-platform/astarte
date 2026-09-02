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

defmodule Astarte.Core.Generators.Mapping.ValueType do
  @moduledoc """
  This module provides generators for any ValueType.
  """
  use ExUnitProperties

  import Astarte.Common.Generators.DateTime
  import Astarte.Common.Generators.Timestamp

  alias Astarte.Core.Mapping.ValueType

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

  @type representation_t :: :native | :api | :database

  @doc """
  List of all astarte's ValueType atoms
  """
  @spec value_type_valid_atoms() :: list(atom())
  def value_type_valid_atoms, do: @valid_atoms

  @doc """
  Generates a valid ValueType
  """
  @spec value_type() :: StreamData.t(ValueType.t())
  def value_type, do: member_of(value_type_valid_atoms())

  @doc """
  Generates a valid value from ValueType
  """
  @spec value_from_type(type :: valid_t()) :: StreamData.t(any())
  def value_from_type(type), do: value_from_type(type, [])

  @doc """
  Generates a valid value using its native, API, or database representation.

  Database strings, blobs, and arrays are nonempty unless `force_allow_unset: true` is supplied.
  """
  @spec value_from_type(type :: valid_t(), options :: keyword()) :: StreamData.t(any())
  def value_from_type(type, options) do
    representation = Keyword.get(options, :representation, :native)
    force_allow_unset = Keyword.get(options, :force_allow_unset, false)
    value_from_type(type, representation, force_allow_unset)
  end

  defp value_from_type(:double, _representation, _force_allow_unset), do: float()

  defp value_from_type(:integer, _representation, _force_allow_unset),
    do: integer(-0x7FFFFFFF..0x7FFFFFFF)

  defp value_from_type(:boolean, _representation, _force_allow_unset), do: boolean()

  defp value_from_type(:longinteger, _representation, _force_allow_unset),
    do: integer(-0x7FFFFFFFFFFFFFFF..0x7FFFFFFFFFFFFFFF)

  defp value_from_type(:string, representation, force_allow_unset),
    do:
      string(:utf8,
        min_length: minimum_length(representation, force_allow_unset),
        max_length: 65_535
      )

  defp value_from_type(:binaryblob, :native, _force_allow_unset),
    do: binary(max_length: 65_535)

  defp value_from_type(:binaryblob, :api, force_allow_unset),
    do:
      binary(
        min_length: minimum_length(:api, force_allow_unset),
        max_length: 65_535
      )
      |> map(&Base.encode64/1)

  defp value_from_type(:binaryblob, :database, force_allow_unset),
    do:
      binary(
        min_length: minimum_length(:database, force_allow_unset),
        max_length: 65_535
      )
      |> map(&%Cyanide.Binary{subtype: :generic, data: &1})

  defp value_from_type(:datetime, :native, _force_allow_unset), do: date_time()

  defp value_from_type(:datetime, :api, _force_allow_unset),
    do: one_of([timestamp(), date_time() |> map(&DateTime.to_iso8601/1)])

  defp value_from_type(:datetime, :database, _force_allow_unset),
    do: one_of([timestamp(), date_time()])

  defp value_from_type(array, representation, force_allow_unset) when is_atom(array),
    do:
      array
      |> type_array()
      |> value_from_type(representation, force_allow_unset)
      |> list_of(
        min_length: minimum_length(representation, force_allow_unset),
        max_length: 1023
      )

  defp minimum_length(:database, false), do: 1
  defp minimum_length(_representation, _force_allow_unset), do: 0

  defp type_array(:doublearray), do: :double
  defp type_array(:integerarray), do: :integer
  defp type_array(:longintegerarray), do: :longinteger
  defp type_array(:booleanarray), do: :boolean
  defp type_array(:stringarray), do: :string
  defp type_array(:binaryblobarray), do: :binaryblob
  defp type_array(:datetimearray), do: :datetime
end
