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

defmodule Astarte.Core.Mapping.DatabaseRetentionPolicy do
  @moduledoc """
  Ecto type for Astarte mapping database retention policies.
  """

  use Ecto.Type

  @type t :: :no_ttl | :use_ttl

  @mapping_policy_no_ttl 1
  @mapping_policy_use_ttl 2
  @valid_atoms [
    :no_ttl,
    :use_ttl
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
      "no_ttl" -> {:ok, :no_ttl}
      "use_ttl" -> {:ok, :use_ttl}
      _ -> :error
    end
  end

  def cast(int) when is_integer(int) do
    load(int)
  end

  def cast(_), do: :error

  def cast!(value) do
    case cast(value) do
      {:ok, policy} ->
        policy

      :error ->
        raise ArgumentError,
          message: "#{inspect(value)} is not a valid database retention policy representation"
    end
  end

  @impl true
  def dump(policy) when is_atom(policy) do
    case policy do
      :no_ttl -> {:ok, @mapping_policy_no_ttl}
      :use_ttl -> {:ok, @mapping_policy_use_ttl}
      _ -> :error
    end
  end

  def dump!(policy) when is_atom(policy) do
    case dump(policy) do
      {:ok, policy_int} ->
        policy_int

      :error ->
        raise ArgumentError,
          message: "#{inspect(policy)} is not a valid database retention policy"
    end
  end

  @impl true
  def load(policy_int) when is_integer(policy_int) do
    case policy_int do
      @mapping_policy_no_ttl -> {:ok, :no_ttl}
      @mapping_policy_use_ttl -> {:ok, :use_ttl}
      _ -> :error
    end
  end

  def to_int(database_retention_policy) when is_atom(database_retention_policy) do
    dump!(database_retention_policy)
  end

  def from_int(int) when is_integer(int) do
    cast!(int)
  end
end
