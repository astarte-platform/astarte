#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.AppEngine.API.Queries do
  alias Astarte.AppEngine.API.KvStore

  alias Astarte.AppEngine.API.Repo

  require Logger
  import Ecto.Query
  @keyspace_does_not_exist_regex ~r/Keyspace (.*) does not exist/

  def fetch_public_key(keyspace_name) do
    case Xandra.Cluster.run(:xandra, &do_fetch_public_key(keyspace_name, &1)) do
      {:ok, pem} ->
        {:ok, pem}

      {:error, %Xandra.ConnectionError{} = err} ->
        Logger.warning("Database connection error #{Exception.message(err)}.",
          tag: "database_connection_error"
        )

        {:error, :database_connection_error}

      {:error, %Xandra.Error{} = err} ->
        handle_xandra_error(err)

      {:error, error} ->
        {:error, error}
    end
  end

  defp do_fetch_public_key(keyspace_name, _conn) do
    schema_query =
      from r in KvStore,
        prefix: ^keyspace_name,
        select: fragment("blobAsVarchar(?)", r.value),
        where: r.group == "auth" and r.key == "jwt_public_key_pem"

    opts = [uuid_format: :binary, consistency: :quorum]

    case safe_query(schema_query, opts) do
      {:ok, %{rows: [[public_key]]}} ->
        {:ok, public_key}

      {:ok, %{num_rows: 0}} ->
        Logger.warning("No public key found in realm #{keyspace_name}.",
          tag: "no_public_key_found"
        )

        {:error, :public_key_not_found}

      {:error, error} ->
        {:error, error}
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

  defp handle_xandra_error(error) do
    %Xandra.Error{message: message} = error

    case Regex.run(@keyspace_does_not_exist_regex, message) do
      [_message, keyspace] ->
        Logger.warning("Keyspace #{keyspace} does not exist.",
          tag: "realm_not_found"
        )

        {:error, :not_existing_realm}

      nil ->
        _ =
          Logger.warning(
            "Database error, cannot get realm public key: #{Exception.message(error)}.",
            tag: "database_error"
          )

        {:error, :database_error}
    end
  end
end
