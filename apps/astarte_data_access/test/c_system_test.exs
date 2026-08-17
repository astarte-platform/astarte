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

defmodule Astarte.DataAccess.CSystemTest do
  # Needs to run synchronously to avoid flakiness with `:expect_change`
  use Astarte.DataAccess.Cases.Database

  alias Astarte.DataAccess.CSystem
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  setup_all %{realm_name: realm_name} do
    keyspace = Realm.keyspace_name(realm_name)

    create_table = """
      CREATE TABLE IF NOT EXISTS #{keyspace}.csystem_test_table (
        id uuid,
        PRIMARY KEY (id)
      )
    """

    %{create_table: create_table}
  end

  setup %{realm_name: realm_name} do
    drop_table = """
      DROP TABLE IF EXISTS #{Realm.keyspace_name(realm_name)}.csystem_test_table
    """

    on_exit(fn ->
      Repo.query(drop_table)
    end)

    :ok
  end

  describe "run_with_schema_agreement/2" do
    test "wraps a schema DDL query", %{create_table: create_table} do
      result =
        CSystem.run_with_schema_agreement(fn ->
          Repo.query(create_table)
        end)

      assert {:ok, _} = result
    end

    test "wraps a schema DDL query with timeout", %{create_table: create_table} do
      result =
        CSystem.run_with_schema_agreement([timeout: 5000], fn ->
          Repo.query(create_table)
        end)

      assert {:ok, _} = result
    end

    test "wraps a schema DDL query with expect_change", %{create_table: create_table} do
      result =
        CSystem.run_with_schema_agreement([expect_change: true], fn ->
          Repo.query(create_table)
        end)

      assert {:ok, _} = result
    end

    test "returns error when schema does not change", %{create_table: create_table} do
      # Create the table so it already exists
      CSystem.execute_schema_change(create_table)

      result =
        CSystem.run_with_schema_agreement([expect_change: true], fn ->
          Repo.query(create_table)
        end)

      assert {:error, :no_schema_change} = result
    end
  end

  describe "execute_schema_change/1" do
    test "executes schema change and returns ok", %{create_table: create_table} do
      result =
        CSystem.execute_schema_change(create_table)

      assert {:ok, _} = result
    end
  end
end
