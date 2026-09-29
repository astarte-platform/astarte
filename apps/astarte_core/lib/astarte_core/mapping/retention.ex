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

defmodule Astarte.Core.Mapping.Retention do
  @moduledoc """
  Ecto type for Astarte mapping retention policies.
  """

  use Ecto.Type

  @type t :: :discard | :volatile | :stored

  @mapping_retention_discard 1
  @mapping_retention_volatile 2
  @mapping_retention_stored 3
  @valid_atoms [
    :discard,
    :volatile,
    :stored
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
      "discard" -> {:ok, :discard}
      "volatile" -> {:ok, :volatile}
      "stored" -> {:ok, :stored}
      _ -> :error
    end
  end

  def cast(int) when is_integer(int) do
    load(int)
  end

  def cast(_), do: :error

  def cast!(value) do
    case cast(value) do
      {:ok, retention} ->
        retention

      :error ->
        raise ArgumentError, message: "#{inspect(value)} is not a valid retention representation"
    end
  end

  @impl true
  def dump(retention) when is_atom(retention) do
    case retention do
      :discard -> {:ok, @mapping_retention_discard}
      :volatile -> {:ok, @mapping_retention_volatile}
      :stored -> {:ok, @mapping_retention_stored}
      _ -> :error
    end
  end

  def dump!(retention) when is_atom(retention) do
    case dump(retention) do
      {:ok, retention_int} -> retention_int
      :error -> raise ArgumentError, message: "#{inspect(retention)} is not a valid retention"
    end
  end

  @impl true
  def load(retention_int) when is_integer(retention_int) do
    case retention_int do
      @mapping_retention_discard -> {:ok, :discard}
      @mapping_retention_volatile -> {:ok, :volatile}
      @mapping_retention_stored -> {:ok, :stored}
      _ -> :error
    end
  end

  def to_int(retention) when is_atom(retention) do
    dump!(retention)
  end

  def from_int(int) when is_integer(int) do
    cast!(int)
  end
end
