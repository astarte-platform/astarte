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
  alias Astarte.Core.Generators.Mapping.Value, as: ValueGenerator
  alias Astarte.Core.Generators.Mapping.ValueType, as: ValueTypeGenerator

  @doc """
  Generates a valid bson value
  """
  @spec bson_value() :: StreamData.t(Cyanide.bson_type())
  @spec bson_value(params :: keyword()) :: StreamData.t(Cyanide.bson_type())
  def bson_value(params \\ []), do: ValueGenerator.value(params) |> to_bson()

  @spec bson_value_type(type :: ValueTypeGenerator.valid_t()) :: StreamData.t(Cyanide.bson_type())
  def bson_value_type(type), do: ValueTypeGenerator.value_from_type(type) |> to_bson(type)

  @doc """
  Convert a Value or ValueType to a valid bson value type
  """
  @spec to_bson(package :: ValueGenerator.t()) :: StreamData.t(Cyanide.bson_type())
  def to_bson(%{path: _path, type: _type, value: _value} = package),
    do: package |> constant() |> to_bson()

  @spec to_bson(gen :: StreamData.t(ValueGenerator.t())) ::
          StreamData.t(Cyanide.bson_type())
  def to_bson(gen),
    do:
      gen
      |> map(&bson_from_map/1)
      |> package_and_encode()

  @spec to_bson(value :: any(), type :: ValueTypeGenerator.valid_t()) ::
          StreamData.t(Cyanide.bson_type())
  def to_bson(value, type) when not is_struct(value, StreamData),
    do: value |> constant() |> to_bson(type)

  @spec to_bson(value :: StreamData.t(any()), type :: ValueTypeGenerator.valid_t()) ::
          StreamData.t(Cyanide.bson_type())
  def to_bson(gen, type),
    do:
      gen
      |> map(&preprocess_type(&1, type))
      |> package_and_encode()

  # Utilities

  defp bson_from_map(%{type: %{} = type, value: %{} = value}) do
    type
    |> Map.new(fn {postfix, type} ->
      value = value |> Map.fetch!(postfix) |> preprocess_type(type)
      {postfix, value}
    end)
  end

  defp bson_from_map(%{type: type, value: value}), do: preprocess_type(value, type)

  defp package_and_encode(gen),
    do:
      gen
      |> bind(&PayloadGenerator.payload(v: &1))
      |> map(&encode/1)

  defp preprocess_type(value, :binaryblob), do: wrap(value)

  defp preprocess_type(values, :binaryblobarray),
    do: Enum.map(values, &preprocess_type(&1, :binaryblob))

  defp preprocess_type(value, _), do: value

  defp encode(value), do: Cyanide.encode!(value)
  defp wrap(value), do: %Cyanide.Binary{subtype: :generic, data: value}
end
