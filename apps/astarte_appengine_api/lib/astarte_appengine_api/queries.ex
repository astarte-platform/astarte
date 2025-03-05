#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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
  alias Astarte.AppEngine.API.Realm
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
    end
  end

  defp do_fetch_public_key(keyspace_name, conn) do
    query = """
    SELECT blobAsVarchar(value)
    FROM #{keyspace_name}.kv_store
    WHERE group='auth' AND key='jwt_public_key_pem';
    """

    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, page} <-
           Xandra.execute(conn, prepared, %{},
             uuid_format: :binary,
             consistency: :quorum
           ) do
      case Enum.to_list(page) do
        [%{"system.blobasvarchar(value)" => pem}] ->
          {:ok, pem}

        [] ->
          {:error, :public_key_not_found}
      end
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

  def check_astarte_health(astarte_keyspace, consistency) do
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
      err -> err
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

      {:error, %Xandra.Error{} = err} ->
        Logger.warning("Health is not good: #{Exception.message(err)}",
          tag: "db_health_check_bad"
        )

        {:error, :health_check_bad}
    end
  end
end
