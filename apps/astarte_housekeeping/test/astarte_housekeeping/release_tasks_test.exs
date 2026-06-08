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

  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.Housekeeping.Helpers.Database
  alias Astarte.Housekeeping.Migrator
  alias Astarte.Housekeeping.ReleaseTasks

  use Mimic

  setup do
    astarte_instance_id = "astarte#{System.unique_integer([:positive])}"
    Database.setup_database_access(astarte_instance_id)

    on_exit(fn ->
      Database.setup_database_access(astarte_instance_id)
      Database.teardown_astarte_keyspace()
    end)

    %{astarte_instance_id: astarte_instance_id}
  end

  describe "ensure_migrated!/0" do
    test "initializes the database" do
      assert :ok = ReleaseTasks.ensure_migrated!()
      assert_initialized()
    end

    test "can be run multiple times" do
      assert :ok = ReleaseTasks.ensure_migrated!()
      assert :ok = ReleaseTasks.ensure_migrated!()
      assert_initialized()
    end

    test "calls the migrator" do
      Migrator
      |> expect(:run_astarte_keyspace_migrations, fn -> :ok end)
      |> expect(:run_realms_migrations, fn -> :ok end)

      assert :ok = ReleaseTasks.ensure_migrated!()
    end
  end

  defp assert_initialized do
    assert {:ok, schema_version} = get_astarte_schema_version()
    assert schema_version == Migrator.latest_astarte_schema_version()
  end

  defp get_astarte_schema_version do
    get_schema_version(Realm.astarte_keyspace_name())
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
end
