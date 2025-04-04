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

defmodule Astarte.Pairing.API.Repo do
  use Ecto.Repo, otp_app: :astarte_pairing_api, adapter: Exandra
  require Ecto.Query

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

    case all(queryable, opts) do
      [item] -> {:ok, item}
      [] -> {:error, error}
      other -> raise Ecto.MultipleResultsError, queryable: queryable, count: length(other)
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
