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

defmodule Astarte.Housekeeping.MigratorTest do
  use ExUnit.Case

  alias Astarte.Housekeeping.Migrator
  alias Astarte.Housekeeping.Engine
  alias Astarte.Housekeeping.Queries
  alias Astarte.Housekeeping.Helpers.Database
  use Mimic

  describe "run migrations, " do
    setup do
      on_exit(fn ->
        Database.destroy_test_astarte_keyspace!(:xandra)
      end)

      Queries.initialize_database()
      Database.edit_with_outdated_column_for_astarte_realms_table!(:xandra)
      :ok
    end

    test "returns ok with complete db" do
      assert :ok = Migrator.run_astarte_keyspace_migrations()
    end

    test "returns ok with incomplete db (missing kv_store table)" do
      Database.destroy_astarte_kv_store_table!(:xandra)

      assert :ok = Migrator.run_astarte_keyspace_migrations()
    end

    test "returns error due do xandra problem" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)

      assert {:error, :database_error} = Migrator.run_astarte_keyspace_migrations()
    end

    test "returns error due do xandra connection problem" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert {:error, :database_connection_error} = Migrator.run_astarte_keyspace_migrations()
    end
  end

  describe "run realms migrations, " do
    setup do
      realm_name = Astarte.Core.Generators.Realm.realm_name() |> Enum.at(0)

      on_exit(fn ->
        Database.destroy_test_astarte_keyspace!(:xandra)
        Database.destroy_test_keyspace!(:xandra, realm_name)
      end)

      Queries.initialize_database()
      :ok = Engine.create_realm(realm_name, "test1publickey", 1, 1, 1, [])
      Database.edit_with_outdated_column_for_astarte_realms_table!(:xandra)
      :ok
    end

    test "returns ok with complete db" do
      assert :ok = Migrator.run_realms_migrations()
    end

    test "returns ok with incomplete db (missing kv_store table)" do
      Database.destroy_astarte_kv_store_table!(:xandra)

      assert :ok = Migrator.run_realms_migrations()
    end

    test "returns error due do xandra problem" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.Error{}} end)

      assert {:error, :database_error} = Migrator.run_realms_migrations()
    end

    test "returns error due do xandra connection problem" do
      Xandra |> stub(:execute, fn _, _, _, _ -> {:error, %Xandra.ConnectionError{}} end)

      assert {:error, :database_connection_error} = Migrator.run_realms_migrations()
    end
  end

  describe "latest schema version is consistent with migrations, " do
    # This test ensures that we're not skipping versions when creating a new astarte migration
    test "for astarte" do
      astarte_migrations_path =
        Application.app_dir(:astarte_housekeeping, Path.join(["priv", "migrations", "astarte"]))

      # We don't specify the .sql extension so we also check if there are migrations with the wrong extension
      astarte_migrations_count =
        Path.join([astarte_migrations_path, "*"])
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
        Path.join([realm_migrations_path, "*.sql"])
        |> Path.wildcard()
        |> Enum.count()

      assert Migrator.latest_realm_schema_version() == realm_migrations_count
    end
  end
end
