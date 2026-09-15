#
# This file is part of Astarte.
#
# Copyright 2017-2024 SECO Mind Srl
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

defmodule Astarte.Core.Interface.Aggregation do
  @moduledoc """
  Ecto type for Astarte interface aggregation modes.
  """

  use Ecto.Type

  @type t :: :individual | :object

  @interface_aggregation_individual 1
  @interface_aggregation_object 2
  @valid_atoms [
    :individual,
    :object
  ]

  @impl true
  def type, do: :integer

  @impl true
  def cast(nil), do: {:ok, nil}

  def cast(atom) when is_atom(atom) do
    if Enum.member?(@valid_atoms, atom) do
      {:ok, atom}
    else
      :error
    end
  end

  def cast(string) when is_binary(string) do
    case string do
      "individual" -> {:ok, :individual}
      "object" -> {:ok, :object}
      _ -> :error
    end
  end

  def cast(int) when is_integer(int) do
    load(int)
  end

  def cast(_), do: :error

  def cast!(value) do
    case cast(value) do
      {:ok, aggregation} ->
        aggregation

      :error ->
        raise ArgumentError,
          message: "#{inspect(value)} is not a valid aggregation representation"
    end
  end

  @impl true
  def dump(aggregation) when is_atom(aggregation) do
    case aggregation do
      :individual -> {:ok, @interface_aggregation_individual}
      :object -> {:ok, @interface_aggregation_object}
      _ -> :error
    end
  end

  def dump!(aggregation) when is_atom(aggregation) do
    case dump(aggregation) do
      {:ok, aggregation_int} -> aggregation_int
      :error -> raise ArgumentError, message: "#{inspect(aggregation)} is not a valid aggregation"
    end
  end

  @impl true
  def load(aggregation_int) when is_integer(aggregation_int) do
    case aggregation_int do
      @interface_aggregation_individual -> {:ok, :individual}
      @interface_aggregation_object -> {:ok, :object}
      _ -> :error
    end
  end

  def to_int(aggregation) when is_atom(aggregation) do
    dump!(aggregation)
  end

  def from_int(int) when is_integer(int) do
    cast!(int)
  end
end
