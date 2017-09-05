defmodule Astarte.RealmManagement.EngineTest do
  use ExUnit.Case
  require Logger

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

  test "install interface" do
    case Astarte.RealmManagement.DatabaseTestHelper.connect_to_test_database() do
      {:ok, _} ->
        assert Astarte.RealmManagement.Engine.get_interfaces_list("autotestrealm") == {:ok, []}

        assert Astarte.RealmManagement.Engine.install_interface("autotestrealm", @test_interface_a_0) == :ok
        assert Astarte.RealmManagement.Engine.install_interface("autotestrealm", @test_interface_b_0) == :ok
        assert Astarte.RealmManagement.Engine.install_interface("autotestrealm", @test_interface_a_1) == {:error, :already_installed_interface}
        assert Astarte.RealmManagement.Engine.install_interface("autotestrealm", @test_interface_a_2) == :ok

        # It is not possible to delete an interface with a major version different than 0
        assert Astarte.RealmManagement.Engine.delete_interface("autotestrealm",  "com.ispirata.Hemera.DeviceLog.Status", 1) == {:error, :forbidden}

        assert Astarte.RealmManagement.Engine.interface_source("autotestrealm", "com.ispirata.Hemera.DeviceLog.Status", 1) == {:ok, @test_interface_a_0}
        assert Astarte.RealmManagement.Engine.interface_source("autotestrealm", "com.ispirata.Hemera.DeviceLog.Configuration", 1) == {:ok, @test_interface_b_0}
        assert Astarte.RealmManagement.Engine.interface_source("autotestrealm", "com.ispirata.Hemera.DeviceLog.Status", 2) == {:ok, @test_interface_a_2}
        assert Astarte.RealmManagement.Engine.interface_source("autotestrealm", "com.ispirata.Hemera.DeviceLog.Missing", 1) == {:error, :interface_not_found}

        assert Astarte.RealmManagement.Engine.list_interface_versions("autotestrealm", "com.ispirata.Hemera.DeviceLog.Configuration") == {:ok, [[major_version: 1, minor_version: 0]]}
        assert Astarte.RealmManagement.Engine.list_interface_versions("autotestrealm", "com.ispirata.Hemera.DeviceLog.Missing") == {:error, :interface_not_found}

        {:ok, interfaces_list} = Astarte.RealmManagement.Engine.get_interfaces_list("autotestrealm")
        sorted_interfaces = interfaces_list
          |> Enum.sort
        assert sorted_interfaces == ["com.ispirata.Hemera.DeviceLog.Configuration", "com.ispirata.Hemera.DeviceLog.Status"]

        Astarte.RealmManagement.DatabaseTestHelper.destroy_local_test_keyspace()
      {:error, msg} -> Logger.warn "Skipped 'install interface' test, database engine says: " <> msg
    end
  end

  @tag :cassandra_only
  test "delete interface" do
    case Astarte.RealmManagement.DatabaseTestHelper.connect_to_test_database() do
      {:ok, _} ->
        assert Astarte.RealmManagement.Engine.install_interface("autotestrealm", @test_draft_interface_a_0) == :ok

        assert Astarte.RealmManagement.Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.Draft"]}
        assert Astarte.RealmManagement.Engine.interface_source("autotestrealm", "com.ispirata.Draft", 0) == {:ok, @test_draft_interface_a_0}
        assert Astarte.RealmManagement.Engine.list_interface_versions("autotestrealm", "com.ispirata.Draft") == {:ok, [[major_version: 0, minor_version: 2]]}

        assert Astarte.RealmManagement.Engine.delete_interface("autotestrealm", "com.ispirata.Draft", 0) == :ok

        assert Astarte.RealmManagement.Engine.get_interfaces_list("autotestrealm") == {:ok, []}
        assert Astarte.RealmManagement.Engine.interface_source("autotestrealm", "com.ispirata.Draft", 0) == {:error, :interface_not_found}
        assert Astarte.RealmManagement.Engine.list_interface_versions("autotestrealm", "com.ispirata.Draft") == {:error, :interface_not_found}

        assert Astarte.RealmManagement.Engine.install_interface("autotestrealm", @test_draft_interface_a_0) == :ok

        assert Astarte.RealmManagement.Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.Draft"]}
        assert Astarte.RealmManagement.Engine.interface_source("autotestrealm", "com.ispirata.Draft", 0) == {:ok, @test_draft_interface_a_0}
        assert Astarte.RealmManagement.Engine.list_interface_versions("autotestrealm", "com.ispirata.Draft") == {:ok, [[major_version: 0, minor_version: 2]]}

        Astarte.RealmManagement.DatabaseTestHelper.destroy_local_test_keyspace()
      {:error, msg} -> Logger.warn "Skipped 'install interface' test, database engine says: " <> msg
    end
  end

end
