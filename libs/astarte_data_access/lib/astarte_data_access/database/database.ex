#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.DataAccess.Database do
  @moduledoc """
  Functions to migrate the astarte database.
  """

  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Database.Migrations
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Ecto.Migrator

  require Logger

  import Ecto.Query

  @astarte_migrations [
    {1, Migrations.Astarte.MigrateSchemaVersion},
    {2, Migrations.Astarte.InitDatabase},
    {3, Migrations.Astarte.DropAstarteSchema},
    {4, Migrations.Astarte.RemoveReplicationFactor},
    {5, Migrations.Astarte.AddDeviceRegistrationLimit},
    {6, Migrations.Astarte.CreateKVStore}
  ]

  @realm_migrations [
    {1, Migrations.Realm.MigrateSchemaVersion},
    {2, Migrations.Realm.InitDatabase},
    {3, Migrations.Realm.CreateGroupedDevices},
    {4, Migrations.Realm.AddGroupsAndInterfaceStats},
    {5, Migrations.Realm.AddDatabaseRetentionTTLAndPolicy},
    {6, Migrations.Realm.AddAttributes},
    {7, Migrations.Realm.CreateDeletionInProgress},
    {8, Migrations.Realm.CreateCapabilitiesType},
    {9, Migrations.Realm.AddCapabilities},
    {10, Migrations.Realm.AddGroupsToDeletionInProgress},
    {11, Migrations.Realm.CreateOwnershipVoucher},
    {12, Migrations.Realm.CreateDeviceSessions},
    {13, Migrations.Realm.AddRequired},
    {14, Migrations.Realm.CreateSessionKeyType},
    {15, Migrations.Realm.DropDeviceSessions},
    {16, Migrations.Realm.RecreateDeviceSessions},
    {17, Migrations.Realm.RemoveReplacementData},
    {18, Migrations.Realm.RemovePrivateKey},
    {19, Migrations.Realm.AddReplacementDataAndRemoteKey},
    {20, Migrations.Realm.AddStatus},
    {21, Migrations.Realm.AddEncryptedToIndividualProperties},
    {22, Migrations.Realm.AddEncryptedToIndividualDatastreams},
    {23, Migrations.Realm.AddEncryptedToEndpoints}
  ]

  @doc """
  Migrates the astarte database and all realm databases.
  """
  def migrate do
    Database.migrate_astarte()
    Database.migrate_realms()

    :ok
  end

  @doc false
  def migrate_realms do
    "Starting to migrate Realms."
    |> Logger.info(tag: "realms_migration_started")

    for realm <- Realm.list_realm_names() do
      Database.migrate_realm(realm)
    end

    "Finished migrating Realms."
    |> Logger.info(tag: "realms_migration_finished")
  end

  @doc false
  def migrate_astarte do
    "Starting to migrate Astarte keyspace."
    |> Logger.info(tag: "astarte_migration_started")

    keyspace = Realm.astarte_keyspace_name()

    migrate_database(keyspace, @astarte_migrations)

    "Finished migrating Astarte keyspace."
    |> Logger.info(tag: "astarte_migration_finished")
  end

  @doc """
  Migrates the realm database
  """
  def migrate_realm(realm_name) do
    "Starting to migrate realm."
    |> Logger.info(tag: "realm_migration_started", realm: realm_name)

    keyspace = Realm.keyspace_name(realm_name)

    migrate_database(keyspace, @realm_migrations)

    "Finished migrating realm."
    |> Logger.info(tag: "realm_migration_finished", realm: realm_name)
  end

  defp migrate_database(keyspace, migrations) do
    # Ensure first migration is complete: populates pre-ecto migrations in the database
    Migrator.run(Repo, migrations, :up, prefix: keyspace, to: 1)
    # Then run migrations again, so that the migration list is re-checked
    Migrator.run(Repo, migrations, :up, prefix: keyspace, all: true)
  end

  @doc false
  def astarte_initialized? do
    keyspace = Realm.astarte_keyspace_name()

    migrations = migrations_for(keyspace)
    has_all_migrations? = Enum.count(migrations) >= 6

    # The last pre-ecto migration was marked as done
    has_last_pre_ecto_migration? = 6 in migrations

    # The last pre-ecto migration was actually performed
    was_last_pre_ecto_migration_done? =
      "device_registration_limit" in columns_of(keyspace, "realms")

    has_all_migrations? and has_last_pre_ecto_migration? and was_last_pre_ecto_migration_done?
  end

  @doc false
  def realm_initialized?(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    migrations = migrations_for(keyspace)
    has_all_migrations? = Enum.count(migrations) >= 23

    # The last pre-ecto migration was marked as done
    has_last_pre_ecto_migration? = 23 in migrations

    # The last pre-ecto migration was actually performed
    was_last_pre_ecto_migration_done? = "encrypted" in columns_of(keyspace, "endpoints")

    has_all_migrations? and has_last_pre_ecto_migration? and was_last_pre_ecto_migration_done?
  end

  defp columns_of(keyspace, table) do
    from(c in "system_schema.columns",
      select: c.column_name,
      where: [keyspace_name: ^keyspace, table_name: ^table]
    )
    |> Repo.all()
  end

  defp migrations_for(keyspace) do
    from(m in migrations_table(), select: m.version)
    |> Repo.all(prefix: keyspace)
  end

  defp migrations_table do
    Application.get_env(:astarte_data_access, Repo, [])
    |> Keyword.get(:migration_source, "schema_migrations")
  end
end
