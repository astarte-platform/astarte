#
# This file is part of Astarte.
#
# Copyright 2019 - 2025 SECO Mind Srl
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

defmodule Astarte.AppEngine.API.Health do
  alias Astarte.DataAccess.Astarte.KvStore
  alias Astarte.DataAccess.Astarte.Realm
  alias Astarte.DataAccess.Repo

  require Logger

  import Ecto.Query

  def get_health do
    astarte_keyspace = Realm.keyspace_name("astarte")

    case check_astarte_health(astarte_keyspace, :quorum) do
      :ok ->
        :ok

      {:error, :database_connection_error} ->
        {:error, :bad_health}

      {:error, :health_check_bad} ->
        case check_astarte_health(astarte_keyspace, :one) do
          :ok -> {:error, :degraded_health}
          _error -> {:error, :bad_health}
        end
    end
  end

  defp check_astarte_health(astarte_keyspace, consistency) do
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
    end
  end

  defp safe_query(ecto_query, opts) do
    {sql, params} = Repo.to_sql(:all, ecto_query)

    # Equivalent to a `Repo.all`, but does not raise if we get a Xandra Error.
    case Repo.query(sql, params, opts) do
      {:ok, result} ->
        {:ok, result}

      {:error, %Xandra.ConnectionError{}} ->
        {:error, :database_connection_error}

      {:error, %Xandra.Error{message: message, reason: reason}} ->
        error_message =
          case message do
            "" -> inspect(reason)
            message -> message
          end

        Logger.warning("Health is not good: #{error_message}", tag: "db_health_check_bad")

        {:error, :health_check_bad}
    end
  end
end
