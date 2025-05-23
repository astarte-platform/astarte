#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.Housekeeping.Migrator do
  require Logger
  alias Astarte.Core.CQLUtils
  alias Astarte.Housekeeping.Config

  alias Astarte.Housekeeping.Queries
  @query_timeout 60_000

  def run_astarte_keyspace_migrations do
    _ = Logger.info("Starting to migrate Astarte keyspace.", tag: "astarte_migration_started")

    with :ok <- ensure_astarte_kv_store(),
         {:ok, astarte_schema_version} <- get_astarte_schema_version(),
         :ok <- migrate_astarte_keyspace_from_version(astarte_schema_version) do
      :ok
    end
  end

  def run_realms_migrations do
    _ = Logger.info("Starting to migrate Realms.", tag: "realms_migration_started")

    with {:ok, realms} <- Queries.list_realms(),
         :ok <- migrate_realms(realms) do
      :ok
    end
  end

  def latest_astarte_schema_version do
    {version, _, _} =
      astarte_migrations_path()
      |> collect_migrations(sorting_order: :descending)
      |> hd()

    version
  end

  def latest_realm_schema_version do
    {version, _, _} =
      realm_migrations_path()
      |> collect_migrations(sorting_order: :descending)
      |> hd()

    version
  end

  defp migrate_realms([]) do
    _ = Logger.info("Finished migrating Realms.", tag: "realms_migration_finished")
    :ok
  end

  defp migrate_realms([realm | tail]) do
    _ = Logger.info("Starting to migrate realm.", tag: "realm_migration_started", realm: realm)

    with {:ok, realm_astarte_schema_version} <- get_realm_astarte_schema_version(realm),
         :ok <- migrate_realm_from_version(realm, realm_astarte_schema_version) do
      migrate_realms(tail)
    end
  end

  defp ensure_astarte_kv_store do
    query = """
    SELECT table_name
    FROM system_schema.tables
    WHERE keyspace_name='#{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}' AND table_name='kv_store'
    """

    with {:ok, %Xandra.Page{} = page} <-
           Xandra.Cluster.execute(:xandra, query, %{}, consistency: :quorum) do
      if Enum.count(page) == 1 do
        :ok
      else
        create_astarte_kv_store()
      end
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp create_astarte_kv_store do
    query = """
    CREATE TABLE #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
    """

    case Xandra.Cluster.execute(:xandra, query, %{},
           consistency: :each_quorum,
           timeout: @query_timeout
         ) do
      {:ok, %Xandra.SchemaChange{}} ->
        :ok

      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp get_astarte_schema_version do
    Xandra.Cluster.run(:xandra, fn conn ->
      with :ok <-
             use_keyspace(
               conn,
               "#{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}"
             ) do
        get_keyspace_astarte_schema_version(conn)
      end
    end)
  end

  defp get_realm_astarte_schema_version(realm_name) do
    Xandra.Cluster.run(:xandra, fn conn ->
      with :ok <-
             use_keyspace(
               conn,
               CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())
             ) do
        get_keyspace_astarte_schema_version(conn)
      end
    end)
  end

  defp use_keyspace(conn, keyspace) do
    case Xandra.execute(conn, "USE #{keyspace}", %{}, timeout: @query_timeout) do
      {:ok, %Xandra.SetKeyspace{}} ->
        :ok

      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp get_keyspace_astarte_schema_version(keyspace_conn) do
    query = """
    SELECT blobAsBigint(value)
    FROM kv_store
    WHERE group='astarte' AND key='schema_version'
    """

    with {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(keyspace_conn, query, %{}, consistency: :quorum) do
      case Enum.to_list(page) do
        [%{"system.blobasbigint(value)" => schema_version}] ->
          {:ok, schema_version}

        [] ->
          # If no entry is found, we assume we're at version 0
          {:ok, 0}
      end
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp migrate_astarte_keyspace_from_version(current_schema_version) do
    _ = Logger.info("Astarte schema version is #{current_schema_version}")

    migrations =
      astarte_migrations_path()
      |> collect_migrations()
      |> filter_migrations(current_schema_version)

    Xandra.Cluster.run(:xandra, [timeout: :infinity], fn conn ->
      with :ok <-
             use_keyspace(
               conn,
               "#{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}"
             ),
           :ok <- execute_migrations(conn, migrations) do
        _ = Logger.info("Finished migrating Astarte keyspace.", tag: "astarte_migration_finished")

        :ok
      end
    end)
  end

  defp migrate_realm_from_version(realm_name, current_schema_version) do
    _ = Logger.info("Realm schema version is #{current_schema_version}", realm: realm_name)

    migrations =
      realm_migrations_path()
      |> collect_migrations()
      |> filter_migrations(current_schema_version)

    Xandra.Cluster.run(:xandra, [timeout: :infinity], fn conn ->
      with :ok <-
             use_keyspace(
               conn,
               CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())
             ),
           :ok <- execute_migrations(conn, migrations) do
        _ =
          Logger.info("Finished migrating realm.",
            tag: "realm_migration_finished",
            realm: realm_name
          )

        :ok
      end
    end)
  end

  defp astarte_migrations_path do
    Application.app_dir(:astarte_housekeeping, Path.join(["priv", "migrations", "astarte"]))
  end

  defp realm_migrations_path do
    Application.app_dir(:astarte_housekeeping, Path.join(["priv", "migrations", "realm"]))
  end

  defp collect_migrations(migrations_path, opts \\ []) do
    sorting_function =
      case Keyword.get(opts, :sorting_order, :ascending) do
        :ascending ->
          fn a, b -> a <= b end

        :descending ->
          fn a, b -> a >= b end
      end

    Path.join([migrations_path, "*.sql"])
    |> Path.wildcard()
    |> Enum.map(&extract_migration_info/1)
    |> Enum.filter(&(&1 != nil))
    |> Enum.sort(sorting_function)
  end

  defp extract_migration_info(file) do
    base = Path.basename(file)

    case Integer.parse(Path.rootname(base)) do
      {version, "_" <> name} -> {version, name, file}
      _ -> nil
    end
  end

  defp filter_migrations(migrations, current_schema_version) do
    Enum.drop_while(migrations, fn {version, _name, _file} ->
      current_schema_version >= version
    end)
  end

  defp execute_migrations(_keyspace_conn, []) do
    :ok
  end

  defp execute_migrations(keyspace_conn, [{version, name, file} | tail]) do
    _ = Logger.info("Executing migration #{version} #{name} using file #{file}")

    with {:ok, query} <- File.read(file),
         _ = Logger.info("Migration query:\n#{query}"),
         {:ok, _result} <- CSystem.execute_schema_change(keyspace_conn, query),
         :ok <- set_schema_version(keyspace_conn, version) do
      execute_migrations(keyspace_conn, tail)
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp set_schema_version(keyspace_conn, schema_version) do
    _ = Logger.info("Setting schema version to #{schema_version}.")

    query = """
    INSERT INTO kv_store
    (group, key, value)
    VALUES
    ('astarte', 'schema_version', bigintAsBlob(:schema_version))
    """

    params = %{"schema_version" => {"bigint", schema_version}}

    with {:ok, %Xandra.Void{}} <-
           Xandra.execute(keyspace_conn, query, params,
             consistency: :each_quorum,
             timeout: @query_timeout
           ) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end
end
