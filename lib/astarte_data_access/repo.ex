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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataAccess.Repo do
  @moduledoc false
  use Ecto.Repo, otp_app: :astarte_data_access, adapter: Exandra
  alias Astarte.DataAccess.Config
  require Ecto.Query
  require Logger

  @impl Ecto.Repo
  def init(_context, config) do
    config =
      Config.xandra_options!()
      |> Keyword.merge(config)

    {:ok, config}
  end

  def insert_to_sql(struct, opts) when is_struct(struct) do
    table = struct.__meta__.source
    insert_to_sql(table, struct, opts)
  end

  def insert_to_sql(table, value, opts) do
    {exandra_opts, opts} = Keyword.split(opts, [:ttl, :overwrite, :timestamp])
    {prefix, _opts} = Keyword.pop(opts, :prefix)

    {keys, values} =
      value
      |> Map.drop([:__struct__, :__meta__])
      |> Enum.unzip()

    keys = Enum.join(keys, ", ")

    {values, params} =
      values
      |> Enum.map(fn
        {:custom, string, values} when is_list(values) -> {string, values}
        {:custom, string, value} -> {string, [value]}
        value -> {"?", [value]}
      end)
      |> Enum.unzip()

    values = Enum.join(values, ", ")

    # We need to get rid of one level of wrapping
    params = Enum.flat_map(params, & &1)

    sql =
      "INSERT INTO #{quote_table(prefix, table)} (#{keys}) VALUES (#{values}) #{insert_suffix(exandra_opts)}"

    {sql, params}
  end

  def fetch(queryable, id, opts \\ []) do
    queryable
    |> query_for_get(id)
    |> fetch_one(opts)
  end

  def fetch_by(queryable, clauses, opts \\ []) do
    queryable
    |> Ecto.Query.where([], ^Enum.to_list(clauses))
    |> fetch_one(opts)
  end

  # source: exandra lib/exandra/connection.ex
  defp quote_table(nil, name), do: quote_table(name)
  defp quote_table(prefix, name), do: [quote_table(prefix), ?., quote_table(name)]
  defp quote_table(name) when is_atom(name), do: quote_table(Atom.to_string(name))
  defp quote_table(name), do: [name]

  # source: exandra lib/exandra/connection.ex
  defp insert_suffix(opts) do
    suffix =
      case Keyword.get(opts, :overwrite, true) do
        true ->
          []

        _ ->
          [" IF NOT EXISTS"]
      end

    suffix =
      case Keyword.get(opts, :ttl, nil) do
        nil -> suffix
        seconds when is_number(seconds) -> suffix ++ [" USING TTL #{seconds}"]
      end

    case Keyword.get(opts, :timestamp, nil) do
      nil ->
        suffix

      epoch_in_microseconds when is_number(epoch_in_microseconds) ->
        suffix ++ [" AND TIMESTAMP #{epoch_in_microseconds}"]
    end
  end

  def fetch_all(queryable, opts \\ []) do
    try do
      {:ok, all(queryable, opts)}
    catch
      error ->
        handle_xandra_error(error)
    end
  end

  def fetch_one(queryable, opts \\ []) do
    {error, opts} = Keyword.pop_first(opts, :error, :not_found)

    case all(queryable, opts) do
      [item] -> {:ok, item}
      [] -> {:error, error}
      other -> raise Ecto.MultipleResultsError, queryable: queryable, count: length(other)
    end
  end

  def safe_insert_all(source, entries, opts \\ []) do
    try do
      {:ok, insert_all(source, entries, opts)}
    catch
      error ->
        handle_xandra_error(error)
    end
  end

  def safe_update_all(queryable, updates, opts \\ []) do
    try do
      {:ok, update_all(queryable, updates, opts)}
    catch
      error ->
        handle_xandra_error(error)
    end
  end

  def safe_delete_all(queryable, opts \\ []) do
    try do
      {:ok, delete_all(queryable, opts)}
    catch
      error ->
        handle_xandra_error(error)
    end
  end

  defp handle_xandra_error(%Xandra.ConnectionError{} = error) do
    _ =
      Logger.warning("Database connection error #{Exception.message(error)}.",
        tag: "database_connection_error"
      )

    {:error, :database_connection_error}
  end

  defp handle_xandra_error(%Xandra.Error{} = error) do
    %Xandra.Error{message: message} = error

    case Regex.run(~r/Keyspace (.*) does not exist/, message) do
      [_message, keyspace] ->
        Logger.warning("Keyspace #{keyspace} does not exist.",
          tag: "realm_not_found"
        )

        {:error, :realm_not_found}

      nil ->
        _ =
          Logger.warning(
            "Database error: #{Exception.message(error)}.",
            tag: "database_error"
          )

        {:error, :database_error}
    end
  end

  @doc """
  Reimplementation of `exists?` from Ecto, without using `select(1)` as scylla does not support it.
  """
  def some?(queryable, opts \\ []) do
    Ecto.Query.exclude(queryable, :select)
    |> Ecto.Query.exclude(:preload)
    |> Ecto.Query.exclude(:order_by)
    |> Ecto.Query.exclude(:distinct)
    |> Ecto.Query.limit(1)

    # no need to rewrite the combinators, let scylla work more it's ok

    # `fetch_one` is safe as we're limiting to 1 here, it should not raise
    case fetch_one(queryable, opts) do
      {:ok, _} -> {:ok, true}
      {:error, _} -> {:ok, false}
    end
  end

  # Copyright: elixir-ecto/ecto
  defp query_for_get(_queryable, nil) do
    raise ArgumentError, "cannot perform Ecto.Repo.get/2 because the given value is nil"
  end

  # Copyright: elixir-ecto/ecto
  defp query_for_get(queryable, id) do
    query = Ecto.Queryable.to_query(queryable)
    schema = assert_schema!(query)

    case schema.__schema__(:primary_key) do
      [pk] ->
        Ecto.Query.from(x in query, where: field(x, ^pk) == ^id)

      pks ->
        raise ArgumentError,
              "Ecto.Repo.get/2 requires the schema #{inspect(schema)} " <>
                "to have exactly one primary key, got: #{inspect(pks)}"
    end
  end

  # Copyright: elixir-ecto/ecto
  defp assert_schema!(%{from: %{source: {_source, schema}}}) when schema != nil, do: schema

  # Copyright: elixir-ecto/ecto
  defp assert_schema!(query) do
    raise Ecto.QueryError,
      query: query,
      message: "expected a from expression with a schema"
  end
end
