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

# TODO: Copied from astarte_data_access PR #71, see: https://github.com/astarte-platform/astarte_data_access/pull/71
# use `astarte_data_access` when it will be merged
defmodule Astarte.RealmManagement.Repo do
  @moduledoc false
  use Ecto.Repo, otp_app: :astarte_realm_management, adapter: Exandra
  require Logger
  alias Astarte.DataAccess.Config
  require Ecto.Query

  @keyspace_does_not_exist_regex ~r/Keyspace (.*) does not exist/

  @impl Ecto.Repo
  def init(_context, config) do
    config =
      Config.xandra_options!()
      |> Keyword.merge(config)

    {:ok, config}
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

  def fetch_one(queryable, opts \\ []) do
    {error, opts} = Keyword.pop_first(opts, :error, :not_found)

    try do
      case all(queryable, opts) do
        [item] -> {:ok, item}
        [] -> {:error, error}
        other -> raise Ecto.MultipleResultsError, queryable: queryable, count: length(other)
      end
    rescue
      err in Xandra.Error ->
        handle_xandra_error(err)

      err in Xandra.ConnectionError ->
        _ =
          Logger.warning("Database connection error #{Exception.message(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  def fetch_all(queryable, opts \\ []) do
    try do
      {:ok, all(queryable, opts)}
    rescue
      err in Xandra.Error ->
        handle_xandra_error(err)

      err in Xandra.ConnectionError ->
        _ =
          Logger.warning("Database connection error #{Exception.message(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp handle_xandra_error(error) do
    %Xandra.Error{message: message} = error

    case Regex.run(@keyspace_does_not_exist_regex, message) do
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
    with {:ok, result} <- fetch_all(queryable, opts) do
      case result do
        [] -> {:ok, false}
        [_something] -> {:ok, true}
      end
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
