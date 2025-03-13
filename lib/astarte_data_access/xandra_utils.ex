#
# This file is part of Astarte.
#
# Copyright 2023 - 2024 SECO Mind Srl
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

defmodule Astarte.DataAccess.XandraUtils do
  alias Astarte.Core.Realm
  alias Astarte.Core.CQLUtils
  alias Astarte.DataAccess.Config

  require Logger

  @spec run(String.t(), (Xandra.Connection.t(), String.t() -> any)) ::
          any | {:error, :invalid_realm_name}
  def run(realm, fun) do
    with :ok <- verify_realm(realm) do
      keyspace = CQLUtils.realm_name_to_keyspace_name(realm, Config.astarte_instance_id!())

      Xandra.Cluster.run(:astarte_data_access_xandra, &fun.(&1, keyspace))
    end
  end

  defp verify_realm(realm_name) do
    case Realm.valid_name?(realm_name) do
      true -> :ok
      false -> {:error, :invalid_realm_name}
    end
  end

  @spec retrieve_page(
          atom | pid | {atom, any} | {:via, atom, any} | DBConnection.t(),
          binary | Xandra.Prepared.t(),
          list | map,
          keyword
        ) ::
          {:error, :database_error}
          | {:error, :database_connection_error}
          | {:ok, Xandra.Page.t()}
  def retrieve_page(conn, statement, params, opts \\ []) do
    with {:ok, prepared} <- prepare_query(conn, statement) do
      opts = opts ++ default_query_opts()

      case Xandra.execute(conn, prepared, params, opts) do
        {:error, %Xandra.Error{} = reason} ->
          _ = Logger.warning("Database error while retrieving data: #{inspect(reason)}")
          {:error, :database_error}

        {:error, %Xandra.ConnectionError{} = reason} ->
          _ =
            Logger.warning("Database connection error while retrieving data: #{inspect(reason)}")

          {:error, :database_connection_error}

        {:ok, %Xandra.Page{} = page} ->
          {:ok, page}
      end
    end
  end

  defp prepare_query(conn, statement, opts \\ []) do
    case Xandra.prepare(conn, statement, opts) do
      {:error, %Xandra.Error{} = reason} ->
        _ = Logger.warning("Database error while preparing query: #{inspect(reason)}")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = reason} ->
        _ = Logger.warning("Database connection error while preparing query: #{inspect(reason)}")
        {:error, :database_connection_error}

      {:ok, %Xandra.Prepared{} = prepared} ->
        {:ok, prepared}
    end
  end

  defp default_query_opts() do
    [uuid_format: :binary, timestamp_format: :integer]
  end
end
