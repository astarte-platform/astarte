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

defmodule Astarte.Housekeeping.Migrator do
  @moduledoc false
  import Ecto.Query

  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.CSystem
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.Housekeeping.Realms.Queries
  alias Astarte.Housekeeping.Realms.Realm, as: HKRealm

  require Logger

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
    %HKRealm{realm_name: realm_name} = realm

    Logger.info("Starting to migrate realm.",
      tag: "realm_migration_started",
      realm_name: realm_name
    )

    with {:ok, realm_astarte_schema_version} <- get_realm_astarte_schema_version(realm_name),
         :ok <- migrate_realm_from_version(realm_name, realm_astarte_schema_version) do
      migrate_realms(tail)
    end
  end

  defp ensure_astarte_kv_store do
    keyspace_name = Realm.astarte_keyspace_name()

    query =
      from t in "system_schema.tables",
        where:
          t.keyspace_name == ^keyspace_name and
            t.table_name == "kv_store",
        select: t.table_name

    consistency = Consistency.domain_model(:read)

    with {:ok, _item} <- Repo.safe_fetch_one(query, consistency: consistency) do
      :ok
    else
      {:error, :not_found} ->
        create_astarte_kv_store()

      {:error, reason} ->
        Logger.warning("Error checking Astarte kv_store existence: #{inspect(reason)}.",
          tag: "database_error"
        )

        {:error, reason}
    end
  end

  defp create_astarte_kv_store do
    query = """
    CREATE TABLE #{Realm.astarte_keyspace_name()}.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
    """

    with {:ok, %{rows: nil, num_rows: 1}} <- CSystem.execute_schema_change(query) do
      :ok
    end
  end

  defp get_astarte_schema_version do
    get_schema_version(Realm.astarte_keyspace_name())
  end

  defp get_realm_astarte_schema_version(realm_name) do
    get_schema_version(Realm.keyspace_name(realm_name))
  end

  defp get_schema_version(keyspace_name) do
    opts = [
      prefix: keyspace_name,
      consistency: Consistency.domain_model(:read)
    ]

    case KvStore.fetch_value("astarte", "schema_version", :big_integer, opts) do
      {:ok, schema_version} -> {:ok, schema_version}
      {:error, :not_found} -> {:ok, 0}
      {:error, reason} -> {:error, reason}
    end
  end

  defp migrate_astarte_keyspace_from_version(current_schema_version) do
    Logger.info("Astarte schema version is #{current_schema_version}")

    keyspace_name = Realm.astarte_keyspace_name()

    migrations =
      astarte_migrations_path()
      |> collect_migrations()
      |> filter_migrations(current_schema_version)

    with :ok <- execute_migrations(keyspace_name, migrations) do
      Logger.info("Finished migrating Astarte keyspace.", tag: "astarte_migration_finished")

      :ok
    end
  end

  defp migrate_realm_from_version(realm_name, current_schema_version) do
    Logger.info("Realm schema version is #{current_schema_version}", realm: realm_name)

    keyspace_name = Realm.keyspace_name(realm_name)

    migrations =
      realm_migrations_path()
      |> collect_migrations()
      |> filter_migrations(current_schema_version)

    with :ok <- execute_migrations(keyspace_name, migrations) do
      Logger.info("Finished migrating realm.",
        tag: "realm_migration_finished",
        realm: realm_name
      )

      :ok
    end
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

    [migrations_path, "*.sql"]
    |> Path.join()
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

  defp execute_migrations(_keyspace_name, []) do
    :ok
  end

  defp execute_migrations(keyspace_name, [{version, name, file} | tail]) do
    Logger.info("Executing migration #{version} #{name} using file #{file}")

    with {:ok, query} <- File.read(file),
         _ = Logger.info("Migration query:\n#{query}"),
         {:ok, _result} <- CSystem.execute_schema_change(query),
         :ok <- set_schema_version(keyspace_name, version) do
      execute_migrations(keyspace_name, tail)
    else
      {:error, %Xandra.Error{} = err} ->
        Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        Logger.warning("Database connection error: #{inspect(err)}.",
          tag: "database_connection_error"
        )

        {:error, :database_connection_error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp set_schema_version(keyspace_name, schema_version) do
    Logger.info("Setting schema version to #{schema_version}.")

    consistency = Consistency.domain_model(:write)

    opts = [
      prefix: keyspace_name,
      consistency: consistency,
      timeout: @query_timeout
    ]

    kv_store_map = %{
      group: "astarte",
      key: "schema_version",
      value: schema_version,
      value_type: :big_integer
    }

    KvStore.insert(kv_store_map, opts)
  end
end
