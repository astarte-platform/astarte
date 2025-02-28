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

defmodule Astarte.RealmManagement.BigInt do
  @moduledoc """
  Ecto type for Cassandra/Scylla bigints, aka 64-bit signed longs.
  """
  use Ecto.Type

  @type t() :: integer()

  @min_bigint -2 ** 63
  @max_bigint 2 ** 63 - 1

  @doc false
  @impl Ecto.Type
  def type, do: :bigint

  @impl Ecto.Type
  @spec load(t() | any()) :: {:ok, t()} | :error
  def load(n) when is_integer(n) and n >= @min_bigint and n <= @max_bigint, do: {:ok, n}
  def load(_), do: :error

  @impl Ecto.Type
  @spec dump(t() | any()) :: {:ok, t()} | :error
  def dump(n), do: load(n)

  @impl Ecto.Type
  @spec cast(t() | any()) :: {:ok, t()} | :error
  def cast(n), do: load(n)
end
