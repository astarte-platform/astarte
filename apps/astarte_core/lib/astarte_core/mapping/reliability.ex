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

defmodule Astarte.Core.Mapping.Reliability do
  @moduledoc """
  Ecto type for Astarte mapping reliability levels.
  """

  use Ecto.Type

  @type t :: :unreliable | :guaranteed | :unique

  @mapping_reliability_unreliable 1
  @mapping_reliability_guaranteed 2
  @mapping_reliability_unique 3
  @valid_atoms [
    :unreliable,
    :guaranteed,
    :unique
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
      "unreliable" -> {:ok, :unreliable}
      "guaranteed" -> {:ok, :guaranteed}
      "unique" -> {:ok, :unique}
      _ -> :error
    end
  end

  def cast(int) when is_integer(int) do
    load(int)
  end

  def cast(_), do: :error

  def cast!(reliability) do
    case cast(reliability) do
      {:ok, reliability} ->
        reliability

      :error ->
        raise ArgumentError,
          message: "#{inspect(reliability)} is not a valid reliability representation"
    end
  end

  @impl true
  def dump(reliability) when is_atom(reliability) do
    case reliability do
      :unreliable -> {:ok, @mapping_reliability_unreliable}
      :guaranteed -> {:ok, @mapping_reliability_guaranteed}
      :unique -> {:ok, @mapping_reliability_unique}
      _ -> :error
    end
  end

  def dump!(reliability) when is_atom(reliability) do
    case dump(reliability) do
      {:ok, reliability_int} -> reliability_int
      :error -> raise ArgumentError, message: "#{inspect(reliability)} is not a valid reliability"
    end
  end

  @impl true
  def load(reliability_int) when is_integer(reliability_int) do
    case reliability_int do
      @mapping_reliability_unreliable -> {:ok, :unreliable}
      @mapping_reliability_guaranteed -> {:ok, :guaranteed}
      @mapping_reliability_unique -> {:ok, :unique}
      _ -> :error
    end
  end

  def to_int(reliability) when is_atom(reliability) do
    dump!(reliability)
  end

  def from_int(int) when is_integer(int) do
    cast!(int)
  end
end
