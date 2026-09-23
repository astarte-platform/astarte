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

defmodule Astarte.DataAccess.DatabaseTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  use Mimic

  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Realms.Realm

  import Astarte.DataAccess.Helpers.Database

  setup_all do
    astarte_instance_id = "test#{System.unique_integer([:positive])}"
    setup_database_access(astarte_instance_id)

    realm_name = "realm#{System.unique_integer([:positive])}"

    %{astarte_instance_id: astarte_instance_id, realm_name: realm_name}
  end

  setup %{astarte_instance_id: astarte_instance_id, realm_name: realm_name} do
    setup_database_access(astarte_instance_id)

    on_exit(fn ->
      setup_database_access(astarte_instance_id)
      teardown_astarte_keyspace()
      teardown_realm_keyspace(realm_name)
    end)
  end

  describe "migrate/0" do
    test "calls astarte and realm migrations" do
      realms =
        list_of(repeatedly(fn -> "realm#{System.unique_integer([:positive])}" end), min_length: 5)
        |> Enum.at(0)

      Database
      |> expect(:migrate_astarte, fn -> :ok end)

      Realm
      |> expect(:list_realm_names, fn -> realms end)

      for realm <- realms do
        Database
        |> expect(:migrate_realm, fn ^realm -> :ok end)
      end

      assert Database.migrate() == :ok
    end
  end

  describe "migrate_astarte/0" do
    test "correctly initializes the astarte keyspace" do
      create_astarte_keyspace()
      assert Database.migrate_astarte() == :ok
      assert Database.astarte_initialized?()
    end

    test "can be run multiple times" do
      create_astarte_keyspace()
      assert Database.migrate_astarte() == :ok
      assert Database.migrate_astarte() == :ok
      assert Database.astarte_initialized?()
    end

    test "creates migrations for pre-ecto migrations" do
      create_housekeeping_astarte()
      assert Database.migrate_astarte() == :ok
      assert Database.astarte_initialized?()
    end

    test "correctly migrates pre-ecto database" do
      create_housekeeping_1_1_0_astarte()
      assert Database.migrate_astarte() == :ok
      assert Database.astarte_initialized?()
    end
  end

  describe "migrate_realm/1" do
    test "correctly initializes the realm keyspace", %{realm_name: realm_name} do
      create_realm_keyspace(realm_name)
      assert Database.migrate_realm(realm_name)
      assert Database.realm_initialized?(realm_name)
    end

    test "can be run multiple times", %{realm_name: realm_name} do
      create_realm_keyspace(realm_name)
      assert Database.migrate_realm(realm_name)
      assert Database.migrate_realm(realm_name)
      assert Database.realm_initialized?(realm_name)
    end

    test "creates migrations for pre-ecto migrations", %{realm_name: realm_name} do
      create_housekeeping_realm(realm_name)
      assert Database.migrate_realm(realm_name)
      assert Database.realm_initialized?(realm_name)
    end

    test "correctly migrates pre-ecto database", %{realm_name: realm_name} do
      create_housekeeping_1_1_0_realm(realm_name)
      assert Database.migrate_realm(realm_name)
      assert Database.realm_initialized?(realm_name)
    end
  end
end
