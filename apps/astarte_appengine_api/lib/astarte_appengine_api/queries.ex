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
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult
  alias Astarte.AppEngine.API.Config
  alias Astarte.Core.CQLUtils

  require Logger

  @keyspace_does_not_exist_regex ~r/Keyspace (.*) does not exist/

  def fetch_public_key(keyspace_name) do
    case Xandra.Cluster.run(:xandra, &do_fetch_public_key(keyspace_name, &1)) do
      {:ok, pem} ->
        {:ok, pem}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
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

  def check_astarte_health(client, consistency) do
    schema_statement = """
      SELECT count(value)
      FROM #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.kv_store
      WHERE group='astarte' AND key='schema_version'
    """

    # no-op, just to check if nodes respond
    # no realm name can contain '_', '^'
    realms_statement = """
      SELECT *
      FROM #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms
      WHERE realm_name='_invalid^name_'
    """

    schema_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(schema_statement)
      |> DatabaseQuery.consistency(consistency)

    realms_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(realms_statement)
      |> DatabaseQuery.consistency(consistency)

    with {:ok, result} <- DatabaseQuery.call(client, schema_query),
         ["system.count(value)": _count] <- DatabaseResult.head(result),
         {:ok, _result} <- DatabaseQuery.call(client, realms_query) do
      :ok
    else
      %{acc: _, msg: err_msg} ->
        _ = Logger.warning("Health is not good: #{err_msg}.", tag: "db_health_check_bad")

        {:error, :health_check_bad}

      {:error, err} ->
        _ =
          Logger.warning("Health is not good, reason: #{inspect(err)}.",
            tag: "db_health_check_bad"
          )

        {:error, :health_check_bad}
    end
  end
end
