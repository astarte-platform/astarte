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

defmodule Astarte.Housekeeping.MigratorTest do
  use ExUnit.Case
  use Mimic

  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm, as: DatabaseRealm
  alias Astarte.Housekeeping.Helpers.Database
  alias Astarte.Housekeeping.Migrator
  alias Astarte.Housekeeping.Realms.Core
  alias Astarte.Housekeeping.Realms.Queries
  alias Astarte.Housekeeping.Realms.Realm

  describe "run migrations, " do
    setup do
      on_exit(fn ->
        Database.teardown_astarte_keyspace()
      end)

      Queries.initialize_database()
      Database.edit_with_outdated_column_for_astarte_realms_table!()
      :ok
    end

    test "returns ok with complete db" do
      assert :ok = Migrator.run_astarte_keyspace_migrations()
    end

    test "returns error due do xandra problem" do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.Error{message: ""}} end)
      assert {:error, :database_error} = Migrator.run_astarte_keyspace_migrations()
    end

    test "returns error due do xandra connection problem" do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)
      assert {:error, :database_connection_error} = Migrator.run_astarte_keyspace_migrations()
    end
  end

  describe "run realms migrations, " do
    setup do
      realm_name = "realm#{System.unique_integer([:positive])}"

      realm = %Realm{
        realm_name: realm_name,
        jwt_public_key_pem: "test1publickey",
        replication_class: "SimpleStrategy",
        replication_factor: 1,
        device_registration_limit: 1,
        datastream_maximum_storage_retention: 1
      }

      on_exit(fn ->
        Database.teardown(realm_name)
      end)

      Queries.initialize_database()
      Core.create_realm(realm, [])
      Database.edit_with_outdated_column_for_astarte_realms_table!()
      :ok
    end

    test "returns ok with complete db" do
      assert :ok = Migrator.run_realms_migrations()
    end

    test "returns ok with missing capabilities" do
      new_realm = "realm#{System.unique_integer([:positive])}"

      realm_migrations_path =
        Application.app_dir(
          :astarte_housekeeping,
          Path.join(["priv", "migrations", "realm"])
        )

      # We don't specify the .sql extension so we also check if there are migrations with the wrong extension
      realm_migrations_count =
        [realm_migrations_path, "*"]
        |> Path.join()
        |> Path.wildcard()
        |> Enum.count()

      Database.create_simple_realm(new_realm)
      assert 0 = realm_schema_version(new_realm)
      assert :ok = Migrator.run_realms_migrations()
      assert realm_migrations_count == realm_schema_version(new_realm)
    end

    test "returns error due do xandra problem" do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.Error{message: ""}} end)
      assert {:error, :database_error} = Migrator.run_realms_migrations()
    end

    test "returns error due do xandra connection problem" do
      Mimic.stub(Xandra, :execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)
      assert {:error, :database_connection_error} = Migrator.run_realms_migrations()
    end
  end

  describe "latest schema version is consistent with migrations, " do
    # This test ensures that we're not skipping versions when creating a new astarte migration
    test "for astarte" do
      astarte_migrations_path =
        Application.app_dir(
          :astarte_housekeeping,
          Path.join(["priv", "migrations", "astarte"])
        )

      # We don't specify the .sql extension so we also check if there are migrations with the wrong extension
      astarte_migrations_count =
        [astarte_migrations_path, "*"]
        |> Path.join()
        |> Path.wildcard()
        |> Enum.count()

      assert Migrator.latest_astarte_schema_version() == astarte_migrations_count
    end

    # This test ensures that we're not skipping versions when creating a new realm migration
    test "for realms" do
      realm_migrations_path =
        Application.app_dir(:astarte_housekeeping, Path.join(["priv", "migrations", "realm"]))

      # We don't specify the .sql extension so we also check if there are migrations with the wrong extension
      realm_migrations_count =
        [realm_migrations_path, "*.sql"]
        |> Path.join()
        |> Path.wildcard()
        |> Enum.count()

      assert Migrator.latest_realm_schema_version() == realm_migrations_count
    end
  end

  defp realm_schema_version(realm_name) do
    keyspace = DatabaseRealm.keyspace_name(realm_name)

    case KvStore.fetch_value("astarte", "schema_version", :big_integer, prefix: keyspace) do
      {:ok, schema_version} -> schema_version
      {:error, :not_found} -> 0
      {:error, _reason} -> flunk("database error fetching schema version for #{realm_name}")
    end
  end
end
