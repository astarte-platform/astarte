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

defmodule Astarte.DataAccess.KvStore do
  use TypedEctoSchema

  alias Astarte.DataAccess.Repo

  import Ecto.Query

  @type value_type :: :binary | :integer | :big_integer | :string
  @source "kv_store"

  @primary_key false
  typed_schema @source do
    field :group, :string, primary_key: true
    field :key, :string, primary_key: true
    field :value, :binary
  end

  @doc """
    Insert a KvStore, allowing type conversion at the database level.

    The Ecto mindset is to finalize the struct on the Elixir side before sending it to \
    the database. This does not work well with the KvStore, where we need to store many types as \
    a blob, but don't care about their actual value on the database side.

    By delegating the conversion to the database, we do not need to manually re-implement all the \
    conversion functions on the elixir side.
  """
  @spec insert(
          %{
            optional(:value_type) => value_type(),
            group: String.t(),
            key: String.t(),
            value: term()
          },
          Keyword.t()
        ) :: :ok | {:error, Exception.t()}
  def insert(kv_store_map, opts \\ []) do
    value_type = Map.get(kv_store_map, :value_type, :binary)

    value_expr =
      case value_type do
        :binary -> "?"
        :integer -> "intAsBlob(?)"
        :big_integer -> "bigintAsBlob(?)"
        :string -> "varcharAsBlob(?)"
      end

    kv_store = %__MODULE__{
      group: kv_store_map.group,
      key: kv_store_map.key,
      value: {:custom, value_expr, kv_store_map.value}
    }

    {sql, params} = Repo.insert_to_sql(kv_store, opts)

    with {:ok, _} <- Repo.query(sql, params, opts) do
      :ok
    end
  end

  @spec fetch_value(String.t(), String.t(), value_type(), Keyword.t()) ::
          {:ok, term()} | {:error, term()}
  def fetch_value(group, key, value_type \\ :binary, opts \\ []) do
    value_expr =
      case value_type do
        :binary -> dynamic([kv], kv.value)
        :integer -> dynamic([kv], fragment("blobAsInt(?)", kv.value))
        :big_integer -> dynamic([kv], fragment("blobAsBigint(?)", kv.value))
        :string -> dynamic([kv], fragment("blobAsVarChar(?)", kv.value))
      end

    query = from(__MODULE__, select: ^value_expr)
    primary_key = [group: group, key: key]

    case Repo.fetch_by(query, primary_key, opts) do
      nil -> {:error, nil}
      {:error, error} -> {:error, error}
      row -> {:ok, row}
    end
  end
end
