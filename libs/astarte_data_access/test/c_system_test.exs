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
  use ExUnit.Case
  alias Astarte.DataAccess.CSystem
  alias Astarte.DataAccess.DatabaseTestHelper
  alias Astarte.DataAccess.Repo

  @test_keyspace "autotestrealm"

  @create_table """
    CREATE TABLE IF NOT EXISTS #{@test_keyspace}.csystem_test_table (
      id uuid,
      PRIMARY KEY (id)
    )
  """

  @drop_table """
    DROP TABLE IF EXISTS #{@test_keyspace}.csystem_test_table
  """

  setup_all do
    on_exit(fn ->
      Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
        DatabaseTestHelper.destroy_local_test_keyspace(conn)
      end)
    end)

    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.create_test_keyspace(conn)
    end)

    :ok
  end

  setup do
    on_exit(fn ->
      Repo.query(@drop_table, [])
    end)

    :ok
  end

  describe "run_with_schema_agreement/2" do
    test "wraps a schema DDL query" do
      result =
        CSystem.run_with_schema_agreement(fn ->
          Repo.query(@create_table, [])
        end)

      assert {:ok, _} = result
    end

    test "wraps a schema DDL query with timeout" do
      result =
        CSystem.run_with_schema_agreement([timeout: 5000], fn ->
          Repo.query(@create_table, [])
        end)

      assert {:ok, _} = result
    end

    test "wraps a schema DDL query with expect_change" do
      result =
        CSystem.run_with_schema_agreement([expect_change: true], fn ->
          Repo.query(@create_table, [])
        end)

      assert {:ok, _} = result
    end

    test "returns error when schema does not change" do
      # Create the table so it already exists
      CSystem.execute_schema_change(@create_table)

      result =
        CSystem.run_with_schema_agreement([expect_change: true], fn ->
          Repo.query(@create_table, [])
        end)

      assert {:error, :no_schema_change} = result
    end
  end

  describe "execute_schema_change/1" do
    test "executes schema change and returns ok" do
      result =
        CSystem.execute_schema_change(@create_table)

      assert {:ok, _} = result
    end
  end
end
