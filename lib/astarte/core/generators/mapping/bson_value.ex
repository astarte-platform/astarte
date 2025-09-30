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

defmodule Astarte.Core.Generators.Mapping.BSONValue do
  @moduledoc """
  This module provides bson value generator.
  """
  use ExUnitProperties

  alias Astarte.Core.Generators.Mapping.Payload, as: PayloadGenerator
  alias Astarte.Core.Generators.Mapping.ValueType, as: ValueTypeGenerator

  @doc """
  Generates a valid bson value based on passed simple value generator
  """
  @spec bson_value(type :: ValueTypeGenerator.valid_t()) ::
          StreamData.t(Cyanide.bson_type())
  def bson_value(type),
    do:
      ValueTypeGenerator.value_from_type(type)
      |> to_bson_value(type)

  @doc """
  Convert a ValueType to a valid bson value type
  """
  @spec to_bson_value(value :: any(), type :: ValueTypeGenerator.valid_t()) ::
          StreamData.t(Cyanide.bson_type())
  def to_bson_value(value, type) when not is_struct(value, StreamData),
    do: value |> constant() |> to_bson_value(type)

  @spec to_bson_value(gen :: StreamData.t(any()), type :: ValueTypeGenerator.valid_t()) ::
          StreamData.t(Cyanide.bson_type())
  def to_bson_value(gen, :binaryblob),
    do:
      gen
      |> map(&wrap/1)
      |> package_and_encode()

  def to_bson_value(gen, :binaryblobarray),
    do:
      gen
      |> map(fn values -> Enum.map(values, &wrap/1) end)
      |> package_and_encode()

  def to_bson_value(gen, _), do: gen |> package_and_encode()

  # Utilities
  defp package_and_encode(gen),
    do:
      gen
      |> bind(&PayloadGenerator.payload(v: &1))
      |> map(&encode/1)

  defp encode(value), do: Cyanide.encode!(value)
  defp wrap(value), do: %Cyanide.Binary{subtype: :generic, data: value}
end
