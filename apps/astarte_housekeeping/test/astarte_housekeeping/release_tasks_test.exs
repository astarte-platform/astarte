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
#

defmodule Astarte.Housekeeping.ReleaseTasksTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Helpers.Database, as: DatabaseHelper
  alias Astarte.Housekeeping.Migrator
  alias Astarte.Housekeeping.Realms.Queries
  alias Astarte.Housekeeping.ReleaseTasks

  import Ecto.Query

  use Mimic

  setup do
    astarte_instance_id = "astarte#{System.unique_integer([:positive])}"
    DatabaseHelper.setup_database_access(astarte_instance_id)

    on_exit(fn ->
      DatabaseHelper.setup_database_access(astarte_instance_id)
      DatabaseHelper.teardown_astarte_keyspace()
    end)

    %{astarte_instance_id: astarte_instance_id}
  end

  describe "ensure_migrated!/0" do
    test "initializes the database" do
      assert :ok = ReleaseTasks.ensure_migrated!()
      assert Database.astarte_initialized?()
    end

    test "can be run multiple times" do
      assert :ok = ReleaseTasks.ensure_migrated!()
      assert :ok = ReleaseTasks.ensure_migrated!()
      assert Database.astarte_initialized?()
    end

    test "calls the migrator" do
      Migrator
      |> expect(:run_realms_migrations, fn -> :ok end)

      assert :ok = ReleaseTasks.ensure_migrated!()
    end

    test "calls data_access for database migrations" do
      Migrator
      |> stub(:run_realms_migrations, fn -> :ok end)

      Queries
      |> stub(:save_keyspace_replication, fn _ -> :ok end)

      Database
      |> expect(:migrate_astarte, fn -> :ok end)
      |> expect(:migrate_realms, fn -> :ok end)

      assert :ok = ReleaseTasks.ensure_migrated!()
    end

    test "creates the astarte keyspace with network topology strategy by default" do
      :ok = ReleaseTasks.ensure_migrated!()
      assert astarte_replication_class() == :network_topology_strategy
    end

    test "creates the astarte keyspace with simple strategy if so configured" do
      Config
      |> expect(:astarte_keyspace_replication_strategy!, fn -> :simple_strategy end)
      |> expect(:astarte_keyspace_replication_factor!, fn -> 1 end)
      |> reject(:astarte_keyspace_network_replication_map!, 0)

      :ok = ReleaseTasks.ensure_migrated!()
      assert astarte_replication_class() == :simple_strategy
    end

    test "the astarte keyspace replication is independent from realm default replication" do
      Config
      |> expect(:astarte_keyspace_replication_strategy!, fn -> :simple_strategy end)
      |> expect(:astarte_keyspace_replication_factor!, fn -> 1 end)
      |> reject(:astarte_keyspace_network_replication_map!, 0)

      :ok = ReleaseTasks.ensure_migrated!()
      assert astarte_replication_class() == :simple_strategy
      assert realm_default_replication_strategy() == :network_topology
    end
  end

  defp astarte_replication_class do
    astarte_keyspace = Realm.astarte_keyspace_name()

    replication =
      from(k in "system_schema.keyspaces", select: k.replication)
      |> Repo.get_by!(keyspace_name: astarte_keyspace)

    case replication["class"] do
      "org.apache.cassandra.locator.SimpleStrategy" -> :simple_strategy
      "org.apache.cassandra.locator.NetworkTopologyStrategy" -> :network_topology_strategy
    end
  end

  defp realm_default_replication_strategy do
    {:ok, %{strategy: strategy}} = Queries.fetch_keyspace_replication()
    strategy
  end
end
