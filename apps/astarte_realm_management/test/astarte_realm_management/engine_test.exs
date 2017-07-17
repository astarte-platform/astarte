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

  test "install interface" do
    case Astarte.RealmManagement.DatabaseTestHelper.connect_to_test_database() do
      {:ok, _} ->
        assert Astarte.RealmManagement.Engine.get_interfaces_list("autotestrealm") == {:ok, []}

        assert Astarte.RealmManagement.Engine.install_interface("autotestrealm", @test_interface_a_0) == :ok
        assert Astarte.RealmManagement.Engine.install_interface("autotestrealm", @test_interface_b_0) == :ok
        assert Astarte.RealmManagement.Engine.install_interface("autotestrealm", @test_interface_a_1) == {:error, :already_installed_interface}
        assert Astarte.RealmManagement.Engine.install_interface("autotestrealm", @test_interface_a_2) == :ok

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

end
