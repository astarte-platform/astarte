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
  use ExUnit.Case

  alias Astarte.Housekeeping.Migrator
  alias Astarte.Housekeeping.Queries
  alias Astarte.Housekeeping.ReleaseTasks
  alias Astarte.Housekeeping.Helpers.Database

  use Mimic

  setup do
    on_exit(fn ->
      Database.destroy_test_astarte_keyspace!(:xandra)
    end)

    :ok
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
      |> expect(:run_astarte_keyspace_migrations, fn _ -> :ok end)
      |> expect(:run_realms_migrations, fn _ -> :ok end)

      assert :ok = ReleaseTasks.ensure_migrated!()
    end
  end

  defp assert_initialized do
    assert {:ok, schema_version} = Queries.get_astarte_schema_version()
    assert schema_version == Migrator.latest_astarte_schema_version()
  end
end
