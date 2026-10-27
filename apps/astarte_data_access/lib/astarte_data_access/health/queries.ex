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

defmodule Astarte.DataAccess.Health.Queries do
  @moduledoc """
  This module provides functions to perform health checks on the Astarte Data Access
  database by executing specific queries with defined consistency levels.
  """
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  import Ecto.Query
  require Logger

  def check_astarte_health(consistency) do
    astarte_keyspace = Realm.astarte_keyspace_name()

    schema_query =
      from kv in KvStore,
        prefix: ^astarte_keyspace,
        where: kv.group == "astarte" and kv.key == "schema_version",
        select: count(kv.value)

    realm_query =
      from Realm,
        prefix: ^astarte_keyspace,
        where: [realm_name: "_invalid^name_"]

    opts = [consistency: consistency]

    with {:ok, _result} <- safe_query(schema_query, opts),
         {:ok, _result} <- safe_query(realm_query, opts) do
      :ok
    else
      error -> error
    end
  end

  defp safe_query(ecto_query, opts) do
    {sql, params} = Repo.to_sql(:all, ecto_query)

    case Repo.query(sql, params, opts) do
      {:ok, result} ->
        {:ok, result}

      {:error, %Xandra.ConnectionError{} = error} ->
        Logger.warning("Database connection error #{Exception.message(error)}.",
          tag: "database_connection_error"
        )

        {:error, :database_connection_error}

      {:error, %Xandra.Error{} = error} ->
        Logger.warning("Health is not good: #{Exception.message(error)}",
          tag: "db_health_check_bad"
        )

        {:error, :health_check_bad}
    end
  end
end
