#
# This file is part of Astarte.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Astarte.Housekeeping.EngineTest do
  use ExUnit.Case
  doctest Astarte.Housekeeping.Engine

  alias Astarte.Housekeeping.Engine
  alias Astarte.Housekeeping.Queries
  alias Astarte.Housekeeping.Helpers.Database
  use Mimic

  describe "create a realm," do
    setup do
      realm_name = Astarte.Core.Generators.Realm.realm_name() |> Enum.at(0)

      on_exit(fn ->
        Database.destroy_test_astarte_keyspace!(:xandra)
        Database.destroy_test_keyspace!(:xandra, realm_name)
      end)

      Queries.initialize_database()
      {:ok, %{realm_name: realm_name}}
    end

    test "creations returns ok", %{realm_name: realm_name} do
      assert :ok = Engine.create_realm(realm_name, "test1publickey", 1, 1, 1, [])
    end

    test "creations returns ok with nil replication factor", %{realm_name: realm_name} do
      assert :ok = Engine.create_realm(realm_name, "test1publickey", nil, 1, 1, [])
    end

    test "creations returns ok with 0 max retentions factor", %{realm_name: realm_name} do
      assert :ok = Engine.create_realm(realm_name, "test1publickey", 1, 1, 0, [])
    end

    test "creations returns error with bigger than nodes replication factor", %{
      realm_name: realm_name
    } do
      assert {:error, {:invalid_replication, error_message}} =
               Engine.create_realm("testrealm", "test1publickey", 10, 1, 1, [])

      assert error_message =~ ">="
    end

    test "async creations returns ok", %{realm_name: realm_name} do
      on_exit(fn ->
        Process.sleep(1000)
        Database.destroy_test_keyspace!(:xandra, "testrealm")
      end)

      assert :ok = Engine.create_realm(realm_name, "test1publickey", 1, 1, 1, async: true)
    end

    test "fails in case of db error", %{realm_name: realm_name} do
      Xandra.Cluster |> stub(:run, fn _, _, _ -> {:error, "generic error"} end)

      assert {:error, "generic error"} =
               Engine.create_realm(realm_name, "test1publickey", 1, 1, 1, [])

      Database.destroy_test_astarte_keyspace!(:xandra)
    end
  end

  describe "delete a realm," do
    setup do
      realm_name = Astarte.Core.Generators.Realm.realm_name() |> Enum.at(0)

      on_exit(fn ->
        Database.destroy_test_astarte_keyspace!(:xandra)
        Database.destroy_test_keyspace!(:xandra, realm_name)
      end)

      Database.setup!(realm_name)
      %{realm_name: realm_name}
    end

    test "deletions returns ok", %{realm_name: realm_name} do
      assert :ok = Engine.delete_realm(realm_name, [])
    end

    test "async deletions returns ok", %{realm_name: realm_name} do
      on_exit(fn ->
        Process.sleep(1000)
        Database.destroy_test_astarte_keyspace!(:xandra)
      end)

      assert :ok = Engine.delete_realm(realm_name, async: true)
    end

    test "fails in case of db error", %{realm_name: realm_name} do
      Xandra.Cluster |> stub(:run, fn _, _, _ -> {:error, "generic error"} end)

      assert {:error, "generic error"} =
               Engine.delete_realm(realm_name)

      Database.destroy_test_astarte_keyspace!(:xandra)
    end
  end

  describe "Realm update" do
    setup do
      realm_name = Astarte.Core.Generators.Realm.realm_name() |> Enum.at(0)

      on_exit(fn ->
        Database.teardown!(realm_name)
      end)

      Queries.initialize_database()
      :ok = Engine.create_realm(realm_name, "test1publickey", 1, 1, 1, [])

      %{realm_name: realm_name}
    end
  end
end
