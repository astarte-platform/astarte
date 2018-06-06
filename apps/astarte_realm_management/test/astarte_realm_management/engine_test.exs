#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.RealmManagement.EngineTest do
  use ExUnit.Case
  require Logger
  alias Astarte.RealmManagement.DatabaseTestHelper
  alias Astarte.RealmManagement.Engine

  @test_interface_a_0 """
  {
     "interface_name": "com.ispirata.Hemera.DeviceLog.Status",
     "version_major": 1,
     "version_minor": 0,
     "type": "properties",
     "quality": "producer",
     "mappings": [
        {
          "path": "/filterRules/%{ruleId}/%{filterKey}/value",
          "type": "string",
          "allow_unset": true
        }
     ]
  }
  """

  @test_interface_a_1 """
  {
     "interface_name": "com.ispirata.Hemera.DeviceLog.Status",
     "version_major": 1,
     "version_minor": 2,
     "type": "properties",
     "quality": "producer",
     "mappings": [
       {
         "path": "/filterRules/%{ruleId}/%{filterKey}/value",
         "type": "string",
         "allow_unset": true
       }
     ]
  }
  """

  @test_interface_a_2 """
  {
     "interface_name": "com.ispirata.Hemera.DeviceLog.Status",
     "version_major": 2,
     "version_minor": 2,
     "type": "properties",
     "quality": "producer",
     "mappings": [
       {
         "path": "/filterRules/%{ruleId}/%{filterKey}/value",
         "type": "string",
         "allow_unset": true
       }
     ]
  }
  """

  @test_interface_b_0 """
  {
    "interface_name": "com.ispirata.Hemera.DeviceLog.Configuration",
    "version_major": 1,
    "version_minor": 0,
    "type": "properties",
    "quality": "consumer",
    "mappings": [
      {
        "path": "/filterRules/%{ruleId}/%{filterKey}/value",
        "type": "string",
        "allow_unset": true
      }
    ]
  }
  """

  @test_draft_interface_a_0 """
  {
    "interface_name": "com.ispirata.Draft",
    "version_major": 0,
    "version_minor": 2,
    "type": "properties",
    "quality": "consumer",
    "mappings": [
      {
        "path": "/filterRules/%{ruleId}/%{filterKey}/value",
        "type": "string",
        "allow_unset": true
      },
      {
        "path": "/filterRules/%{ruleId}/%{filterKey}/foo",
        "type": "boolean",
        "allow_unset": false
      }
    ]
  }
  """

  setup do
    with {:ok, client} <- DatabaseTestHelper.connect_to_test_database() do
      DatabaseTestHelper.seed_test_data(client)
    end
  end

  setup_all do
    with {:ok, client} <- DatabaseTestHelper.connect_to_test_database() do
      DatabaseTestHelper.create_test_keyspace(client)
    end

    on_exit(fn ->
      with {:ok, client} <- DatabaseTestHelper.connect_to_test_database() do
        DatabaseTestHelper.drop_test_keyspace(client)
      end
    end)
  end

  test "install interface" do
    case DatabaseTestHelper.connect_to_test_database() do
      {:ok, _} ->
        assert Engine.get_interfaces_list("autotestrealm") == {:ok, []}

        assert Engine.install_interface("autotestrealm", @test_interface_a_0) == :ok
        assert Engine.install_interface("autotestrealm", @test_interface_b_0) == :ok

        assert Engine.install_interface("autotestrealm", @test_interface_a_1) ==
                 {:error, :already_installed_interface}

        assert Engine.install_interface("autotestrealm", @test_interface_a_2) == :ok

        # It is not possible to delete an interface with a major version different than 0
        assert Engine.delete_interface("autotestrealm", "com.ispirata.Hemera.DeviceLog.Status", 1) ==
                 {:error, :forbidden}

        assert Engine.interface_source("autotestrealm", "com.ispirata.Hemera.DeviceLog.Status", 1) ==
                 {:ok, @test_interface_a_0}

        assert Engine.interface_source(
                 "autotestrealm",
                 "com.ispirata.Hemera.DeviceLog.Configuration",
                 1
               ) == {:ok, @test_interface_b_0}

        assert Engine.interface_source("autotestrealm", "com.ispirata.Hemera.DeviceLog.Status", 2) ==
                 {:ok, @test_interface_a_2}

        assert Engine.interface_source(
                 "autotestrealm",
                 "com.ispirata.Hemera.DeviceLog.Missing",
                 1
               ) == {:error, :interface_not_found}

        assert Engine.list_interface_versions(
                 "autotestrealm",
                 "com.ispirata.Hemera.DeviceLog.Configuration"
               ) == {:ok, [[major_version: 1, minor_version: 0]]}

        assert Engine.list_interface_versions(
                 "autotestrealm",
                 "com.ispirata.Hemera.DeviceLog.Missing"
               ) == {:error, :interface_not_found}

        {:ok, interfaces_list} = Engine.get_interfaces_list("autotestrealm")

        sorted_interfaces =
          interfaces_list
          |> Enum.sort()

        assert sorted_interfaces == [
                 "com.ispirata.Hemera.DeviceLog.Configuration",
                 "com.ispirata.Hemera.DeviceLog.Status"
               ]

      {:error, msg} ->
        Logger.warn("Skipped 'install interface' test, database engine says: " <> msg)
    end
  end

  test "delete interface" do
    case DatabaseTestHelper.connect_to_test_database() do
      {:ok, _} ->
        assert Engine.install_interface("autotestrealm", @test_draft_interface_a_0) == :ok

        assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.Draft"]}

        assert Engine.interface_source("autotestrealm", "com.ispirata.Draft", 0) ==
                 {:ok, @test_draft_interface_a_0}

        assert Engine.list_interface_versions("autotestrealm", "com.ispirata.Draft") ==
                 {:ok, [[major_version: 0, minor_version: 2]]}

        assert Engine.delete_interface("autotestrealm", "com.ispirata.Draft", 0) == :ok

        assert Engine.get_interfaces_list("autotestrealm") == {:ok, []}

        assert Engine.interface_source("autotestrealm", "com.ispirata.Draft", 0) ==
                 {:error, :interface_not_found}

        assert Engine.list_interface_versions("autotestrealm", "com.ispirata.Draft") ==
                 {:error, :interface_not_found}

        assert Engine.install_interface("autotestrealm", @test_draft_interface_a_0) == :ok

        assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.Draft"]}

        assert Engine.interface_source("autotestrealm", "com.ispirata.Draft", 0) ==
                 {:ok, @test_draft_interface_a_0}

        assert Engine.list_interface_versions("autotestrealm", "com.ispirata.Draft") ==
                 {:ok, [[major_version: 0, minor_version: 2]]}

      {:error, msg} ->
        Logger.warn("Skipped 'install interface' test, database engine says: " <> msg)
    end
  end

  test "get JWT public key PEM with existing realm" do
    DatabaseTestHelper.connect_to_test_database()

    assert Engine.get_jwt_public_key_pem("autotestrealm") ==
             {:ok, DatabaseTestHelper.jwt_public_key_pem_fixture()}
  end

  test "get JWT public key PEM with unexisting realm" do
    assert Engine.get_jwt_public_key_pem("notexisting") == {:error, :realm_not_found}
  end

  test "update JWT public key PEM" do
    DatabaseTestHelper.connect_to_test_database()

    new_pem = "not_exactly_a_PEM_but_will_do"
    assert Engine.update_jwt_public_key_pem("autotestrealm", new_pem) == :ok
    assert Engine.get_jwt_public_key_pem("autotestrealm") == {:ok, new_pem}

    # Put the PEM fixture back
    assert Engine.update_jwt_public_key_pem(
             "autotestrealm",
             DatabaseTestHelper.jwt_public_key_pem_fixture()
           ) == :ok

    assert Engine.get_jwt_public_key_pem("autotestrealm") ==
             {:ok, DatabaseTestHelper.jwt_public_key_pem_fixture()}
  end

  test "update JWT public key PEM with unexisting realm" do
    assert Engine.get_jwt_public_key_pem("notexisting") == {:error, :realm_not_found}
  end
end
