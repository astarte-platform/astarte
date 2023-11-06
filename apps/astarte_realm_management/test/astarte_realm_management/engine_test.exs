#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
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

defmodule Astarte.RealmManagement.EngineTest do
  use ExUnit.Case
  require Logger
  alias Astarte.Core.CQLUtils
  alias Astarte.DataAccess.Database
  alias Astarte.RealmManagement.DatabaseTestHelper
  alias Astarte.RealmManagement.DatabaseFixtures
  alias Astarte.RealmManagement.Engine
  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Device

  @test_interface_a_0 """
  {
     "interface_name": "com.ispirata.Hemera.DeviceLog.Status",
     "version_major": 1,
     "version_minor": 0,
     "type": "properties",
     "ownership": "device",
     "mappings": [
        {
          "endpoint": "/filterRules/%{ruleId}/%{filterKey}/value",
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
     "ownership": "device",
     "mappings": [
       {
         "endpoint": "/filterRules/%{ruleId}/%{filterKey}/value",
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
     "ownership": "device",
     "mappings": [
       {
         "endpoint": "/filterRules/%{ruleId}/%{filterKey}/value",
         "type": "string",
         "allow_unset": true
       }
     ]
  }
  """

  @test_interface_a_name_mismatch """
  {
     "interface_name": "com.ispirata.Hemera.devicelog.Status",
     "version_major": 2,
     "version_minor": 2,
     "type": "properties",
     "ownership": "device",
     "mappings": [
       {
         "endpoint": "/filterRules/%{ruleId}/%{filterKey}/value",
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
    "ownership": "server",
    "mappings": [
      {
        "endpoint": "/filterRules/%{ruleId}/%{filterKey}/value",
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
    "ownership": "server",
    "mappings": [
      {
        "endpoint": "/filterRules/%{ruleId}/%{filterKey}/value",
        "type": "string",
        "allow_unset": true
      },
      {
        "endpoint": "/filterRules/%{ruleId}/%{filterKey}/foo",
        "type": "boolean"
      }
    ]
  }
  """

  @test_draft_interface_b_0 """
  {
   "interface_name": "com.ObjectAggregation",
   "version_major": 0,
   "version_minor": 3,
   "type": "datastream",
   "ownership": "device",
   "aggregation": "object",
   "description": "Interface description.",
   "doc": "Interface documentation.",
   "mappings": [
      {
        "endpoint": "/x",
        "type": "double",
        "explicit_timestamp": true
      },
      {
        "endpoint": "/y",
        "type": "double",
        "explicit_timestamp": true
      }
    ]
  }
  """

  @test_draft_interface_b_1 """
  {
   "interface_name": "com.ObjectAggregation",
   "version_major": 0,
   "version_minor": 4,
   "type": "datastream",
   "ownership": "device",
   "aggregation": "object",
   "description": "Interface description.",
   "doc": "Interface documentation.",
   "mappings": [
      {
        "endpoint": "/x",
        "type": "double",
        "explicit_timestamp": true
      },
      {
        "endpoint": "/y",
        "type": "double",
        "explicit_timestamp": true
      },
      {
        "endpoint": "/z",
        "type": "double",
        "explicit_timestamp": true
      },
      {
        "endpoint": "/speed",
        "type": "double",
        "explicit_timestamp": true
      }

    ]
  }
  """

  @test_draft_interface_c_0 """
  {
   "interface_name": "com.ispirata.TestDatastream",
   "version_major": 0,
   "version_minor": 10,
   "type": "datastream",
   "ownership": "device",
   "mappings": [
      {
        "endpoint": "/%{sensorId}/realValues",
        "type": "double",
        "description": "A real values test mapping.",
        "doc": "Real values mappings documentation."
      },
      {
        "endpoint": "/%{sensorId}/integerValues",
        "type": "integer",
        "description": "A integer values test mapping."
      }
    ]
  }
  """

  @test_draft_interface_c_1 """
  {
   "interface_name": "com.ispirata.TestDatastream",
   "version_major": 0,
   "version_minor": 15,
   "type": "datastream",
   "ownership": "device",
   "mappings": [
      {
        "endpoint": "/%{sensorId}/realValues",
        "type": "double",
        "description": "A real values test mapping.",
        "doc": "Real values mappings documentation."
      },
      {
        "endpoint": "/%{sensorId}/integerValues",
        "type": "integer",
        "description": "A integer values test mapping."
      },
      {
        "endpoint": "/%{sensorId}/stringValues",
        "type": "string"
      },
      {
        "endpoint": "/testLong/something",
        "type": "longinteger"
      }
    ]
  }
  """

  @test_draft_interface_c_downgrade """
  {
   "interface_name": "com.ispirata.TestDatastream",
   "version_major": 0,
   "version_minor": 14,
   "type": "datastream",
   "ownership": "device",
   "mappings": [
      {
        "endpoint": "/%{sensorId}/realValues",
        "type": "double"
      },
      {
        "endpoint": "/%{sensorId}/integerValues",
        "type": "integer"
      },
      {
        "endpoint": "/%{sensorId}/stringValues",
        "type": "string"
      },
      {
        "endpoint": "/testLong/something/downgrade",
        "type": "longinteger"
      }
    ]
  }
  """

  @test_draft_interface_c_invalid_change """
  {
   "interface_name": "com.ispirata.TestDatastream",
   "version_major": 0,
   "version_minor": 15,
   "type": "properties",
   "ownership": "device",
   "mappings": [
      {
        "endpoint": "/%{sensorId}/realValues",
        "type": "double"
      },
      {
        "endpoint": "/%{sensorId}/integerValues",
        "type": "integer"
      },
      {
        "endpoint": "/%{sensorId}/stringValues",
        "type": "string"
      },
      {
        "endpoint": "/testLong/something",
        "type": "longinteger"
      }
    ]
  }
  """

  @test_draft_interface_c_incompatible_change """
  {
   "interface_name": "com.ispirata.TestDatastream",
   "version_major": 0,
   "version_minor": 15,
   "type": "datastream",
   "ownership": "device",
   "mappings": [
      {
        "endpoint": "/%{sensorId}/realValues",
        "type": "double"
      },
      {
        "endpoint": "/%{sensorId}/integerValues",
        "type": "double"
      },
      {
        "endpoint": "/%{sensorId}/stringValues",
        "type": "string"
      },
      {
        "endpoint": "/testLong/something",
        "type": "longinteger"
      }
    ]
  }
  """

  @test_draft_interface_c_wrong_update """
  {
   "interface_name": "com.ispirata.TestDatastream",
   "version_major": 0,
   "version_minor": 20,
   "type": "datastream",
   "ownership": "device",
   "mappings": [
      {
        "endpoint": "/%{sensorId}/realValues",
        "type": "double"
      }
    ]
  }
  """

  @test_interface_d_0 """
  {
    "interface_name": "org.astarte-platform.Values",
    "version_major": 1,
    "version_minor": 0,
    "type": "datastream",
    "ownership": "device",
    "description": "The description.",
    "doc": "The docs.",
    "mappings": [
        {
            "endpoint": "/%{sensor_id}/value",
            "type": "double",
            "explicit_timestamp": true,
            "description": "Description.",
            "doc": "Docs."
        }
    ]
  }
  """

  @test_interface_d_1 """
  {
    "interface_name": "org.astarte-platform.Values",
    "version_major": 1,
    "version_minor": 1,
    "type": "datastream",
    "ownership": "device",
    "description": "The description.",
    "doc": "The docs.",
    "mappings": [
        {
            "endpoint": "/%{sensor_id}/value",
            "type": "double",
            "description": "Updated description.",
            "doc": "Updated docs.",
            "retention": "stored",
            "expiry": 7200
        }
    ]
  }
  """

  @test_interface_d_incompatible_change """
  {
    "interface_name": "org.astarte-platform.Values",
    "version_major": 1,
    "version_minor": 2,
    "type": "datastream",
    "ownership": "device",
    "description": "The description.",
    "doc": "The docs.",
    "mappings": [
        {
            "endpoint": "/%{sensor_id}/value",
            "type": "string",
            "explicit_timestamp": false,
            "description": "Updated description.",
            "doc": "Updated docs.",
            "retention": "stored",
            "expiry": 7200
        }
    ]
  }
  """

  @test_interface_e_0 """
  {
    "interface_name": "com.autotest.AggregateValuesUpdate",
    "version_major": 1,
    "version_minor": 0,
    "type": "datastream",
    "ownership": "device",
    "description": "The description.",
    "doc": "The docs.",
    "aggregation": "object",
    "mappings": [
        {
            "endpoint": "/%{sensor_id}/value1",
            "type": "double",
            "description": "Description.",
            "doc": "Docs."
        },
        {
            "endpoint": "/%{sensor_id}/value2",
            "type": "double",
            "description": "Description.",
            "doc": "Docs."
        }
    ]
  }
  """

  @test_interface_e_1 """
  {
    "interface_name": "com.autotest.AggregateValuesUpdate",
    "version_major": 1,
    "version_minor": 1,
    "type": "datastream",
    "ownership": "device",
    "description": "The description.",
    "doc": "The docs.",
    "aggregation": "object",
    "mappings": [
        {
            "endpoint": "/%{sensor_id}/value1",
            "type": "double",
            "explicit_timestamp": true,
            "description": "Updated description.",
            "doc": "Updated docs.",
            "retention": "stored",
            "expiry": 1000
        },
        {
            "endpoint": "/%{sensor_id}/value2",
            "type": "double",
            "explicit_timestamp": true,
            "description": "Other updated description.",
            "doc": "Other updated docs.",
            "retention": "stored",
            "expiry": 1000
        }
    ]
  }
  """

  @test_interface_e_incompatible_change """
  {
    "interface_name": "com.autotest.AggregateValuesUpdate",
    "version_major": 1,
    "version_minor": 1,
    "type": "datastream",
    "ownership": "device",
    "description": "The description.",
    "doc": "The docs.",
    "aggregation": "object",
    "mappings": [
        {
            "endpoint": "/%{sensor_id}/value1",
            "type": "double",
            "explicit_timestamp": true,
            "description": "Updated description.",
            "doc": "Updated docs.",
            "retention": "stored",
            "expiry": 1000
        },
        {
            "endpoint": "/%{sensor_id}/value2",
            "type": "double",
            "explicit_timestamp": true,
            "description": "Other updated description.",
            "doc": "Other updated docs.",
            "retention": "stored",
            "expiry": 20000
        }
    ]
  }
  """

  @test_interface_f_0 """
  {
    "interface_name": "com.autotest.AggregateValuesUpdateAndAdd",
    "version_major": 1,
    "version_minor": 0,
    "type": "datastream",
    "ownership": "device",
    "description": "The description.",
    "doc": "The docs.",
    "aggregation": "object",
    "mappings": [
        {
            "endpoint": "/%{sensor_id}/value1",
            "type": "string",
            "description": "Description.",
            "doc": "Docs."
        }
    ]
  }
  """

  @test_interface_f_1 """
  {
    "interface_name": "com.autotest.AggregateValuesUpdateAndAdd",
    "version_major": 1,
    "version_minor": 1,
    "type": "datastream",
    "ownership": "device",
    "description": "The description.",
    "doc": "The docs.",
    "aggregation": "object",
    "mappings": [
        {
            "endpoint": "/%{sensor_id}/value1",
            "type": "string",
            "explicit_timestamp": true,
            "description": "Updated description.",
            "doc": "Updated docs.",
            "retention": "volatile",
            "expiry": 2000
        },
        {
            "endpoint": "/%{sensor_id}/value2",
            "type": "double",
            "explicit_timestamp": true,
            "description": "New description.",
            "doc": "New docs.",
            "retention": "volatile",
            "expiry": 2000
        }
    ]
  }
  """

  @test_draft_interface_g_0 """
  {
   "interface_name": "com.astarte.ObjectAggregationIface",
   "version_major": 0,
   "version_minor": 3,
   "type": "datastream",
   "ownership": "device",
   "aggregation": "object",
   "description": "Interface description.",
   "doc": "Interface documentation.",
   "mappings": [
      {
        "endpoint": "/x",
        "type": "double",
        "explicit_timestamp": true
      },
      {
        "endpoint": "/y",
        "type": "double",
        "explicit_timestamp": true
      }
    ]
  }
  """

  @test_trigger_policy_1 """
    {
      "name": "aname",
      "error_handlers": [
        {
          "on" : "any_error",
          "strategy": "retry"
        }
      ],
      "maximum_capacity": 300,
      "retry_times": 10,
      "event_ttl": 10
    }
  """

  @test_trigger_policy_2 """
    {
      "name": "anothername",
      "error_handlers": [
        {
          "on" : "any_error",
          "strategy": "retry"
        }
      ],
      "maximum_capacity": 300,
      "retry_times": 10,
      "event_ttl": 10
    }
  """

  @test_realm_name "autotestrealm"

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
    assert Engine.get_interfaces_list("autotestrealm") == {:ok, []}

    assert Engine.install_interface("autotestrealm", @test_interface_a_0) == :ok
    assert Engine.install_interface("autotestrealm", @test_interface_b_0) == :ok

    assert Engine.install_interface("autotestrealm", @test_interface_a_1) ==
             {:error, :already_installed_interface}

    assert Engine.install_interface("autotestrealm", @test_interface_a_2) == :ok

    # It is not possible to delete an interface with a major version different than 0
    assert Engine.delete_interface("autotestrealm", "com.ispirata.Hemera.DeviceLog.Status", 1) ==
             {:error, :forbidden}

    assert unpack_source(
             Engine.interface_source("autotestrealm", "com.ispirata.Hemera.DeviceLog.Status", 1)
           ) == unpack_source({:ok, @test_interface_a_0})

    assert unpack_source(
             Engine.interface_source(
               "autotestrealm",
               "com.ispirata.Hemera.DeviceLog.Configuration",
               1
             )
           ) == unpack_source({:ok, @test_interface_b_0})

    assert unpack_source(
             Engine.interface_source("autotestrealm", "com.ispirata.Hemera.DeviceLog.Status", 2)
           ) == unpack_source({:ok, @test_interface_a_2})

    assert unpack_source(
             Engine.interface_source(
               "autotestrealm",
               "com.ispirata.Hemera.DeviceLog.Missing",
               1
             )
           ) == unpack_source({:error, :interface_not_found})

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
  end

  test "interface name case mismatch fail" do
    assert Engine.install_interface("autotestrealm", @test_interface_a_0) == :ok

    assert Engine.install_interface("autotestrealm", @test_interface_a_name_mismatch) ==
             {:error, :interface_name_collision}
  end

  test "install of interfaces whose names are mapped to the same table fail" do
    test_interface = """
    {
       "interface_name": "com.ispirataDevice-Log.Status",
       "version_major": 1,
       "version_minor": 2,
       "type": "properties",
       "ownership": "device",
       "mappings": [
         {
           "endpoint": "/filterRules/%{ruleId}/%{filterKey}/value",
           "type": "string",
           "allow_unset": true
         }
       ]
    }
    """

    test_conflicting_interface = """
    {
       "interface_name": "com.ispirata-DeviceLog.Status",
       "version_major": 1,
       "version_minor": 2,
       "type": "properties",
       "ownership": "device",
       "mappings": [
         {
           "endpoint": "/filterRules/%{ruleId}/%{filterKey}/value",
           "type": "string",
           "allow_unset": true
         }
       ]
    }
    """

    assert Engine.install_interface("autotestrealm", test_interface) == :ok

    assert Engine.install_interface("autotestrealm", test_conflicting_interface) ==
             {:error, :interface_name_collision}
  end

  test "delete interface" do
    assert Engine.install_interface("autotestrealm", @test_draft_interface_a_0) == :ok

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.Draft"]}

    assert unpack_source(Engine.interface_source("autotestrealm", "com.ispirata.Draft", 0)) ==
             unpack_source({:ok, @test_draft_interface_a_0})

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.Draft") ==
             {:ok, [[major_version: 0, minor_version: 2]]}

    {:ok, client} = Database.connect(realm: "autotestrealm")

    d = :crypto.strong_rand_bytes(16)

    e1 =
      CQLUtils.endpoint_id(
        "com.ispirata.TestDatastream",
        0,
        "/filterRules/%{ruleId}/%{filterKey}/value"
      )

    p1 = "/filterRules/0/TEST/value"
    DatabaseTestHelper.seed_properties_test_value(client, d, "com.ispirata.Draft", 0, e1, p1)

    assert DatabaseTestHelper.count_interface_properties_for_device(
             client,
             d,
             "com.ispirata.Draft",
             0
           ) == 1

    assert Engine.delete_interface("autotestrealm", "com.ispirata.Draft", 0) == :ok

    assert DatabaseTestHelper.count_interface_properties_for_device(
             client,
             d,
             "com.ispirata.Draft",
             0
           ) == 0

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, []}

    assert Engine.interface_source("autotestrealm", "com.ispirata.Draft", 0) ==
             {:error, :interface_not_found}

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.Draft") ==
             {:error, :interface_not_found}

    assert Engine.install_interface("autotestrealm", @test_draft_interface_a_0) == :ok

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.Draft"]}

    assert unpack_source(Engine.interface_source("autotestrealm", "com.ispirata.Draft", 0)) ==
             unpack_source({:ok, @test_draft_interface_a_0})

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.Draft") ==
             {:ok, [[major_version: 0, minor_version: 2]]}
  end

  test "install object aggregated interface" do
    assert Engine.install_interface("autotestrealm", @test_draft_interface_b_0) == :ok

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ObjectAggregation"]}

    assert Engine.list_interface_versions("autotestrealm", "com.ObjectAggregation") ==
             {:ok, [[major_version: 0, minor_version: 3]]}

    assert Engine.delete_interface("autotestrealm", "com.ObjectAggregation", 0) == :ok

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, []}

    assert Engine.list_interface_versions("autotestrealm", "com.ObjectAggregation") ==
             {:error, :interface_not_found}

    # Try again so we can verify if it has been completely deleted

    assert Engine.install_interface("autotestrealm", @test_draft_interface_b_0) == :ok

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ObjectAggregation"]}

    assert Engine.list_interface_versions("autotestrealm", "com.ObjectAggregation") ==
             {:ok, [[major_version: 0, minor_version: 3]]}

    assert Engine.delete_interface("autotestrealm", "com.ObjectAggregation", 0) == :ok
  end

  test "delete datastream interface" do
    assert Engine.install_interface("autotestrealm", @test_draft_interface_c_0) == :ok

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.TestDatastream"]}

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.TestDatastream") ==
             {:ok, [[major_version: 0, minor_version: 10]]}

    {:ok, client} = Database.connect(realm: "autotestrealm")

    d = :crypto.strong_rand_bytes(16)
    e1 = CQLUtils.endpoint_id("com.ispirata.TestDatastream", 0, "/%{sensorId}/realValues")
    p1 = "/0/realValues"

    DatabaseTestHelper.seed_datastream_test_data(
      client,
      d,
      "com.ispirata.TestDatastream",
      0,
      e1,
      p1
    )

    e2 = CQLUtils.endpoint_id("com.ispirata.TestDatastream", 0, "/%{sensorId}/integerValues")
    p2 = "/0/integerValues"

    DatabaseTestHelper.seed_datastream_test_data(
      client,
      d,
      "com.ispirata.TestDatastream",
      0,
      e2,
      p2
    )

    assert Engine.delete_interface("autotestrealm", "com.ispirata.TestDatastream", 0) == :ok

    assert DatabaseTestHelper.count_rows_for_datastream(
             client,
             d,
             "com.ispirata.TestDatastream",
             0,
             e1,
             p1
           ) == 0

    assert DatabaseTestHelper.count_rows_for_datastream(
             client,
             d,
             "com.ispirata.TestDatastream",
             0,
             e2,
             p2
           ) == 0
  end

  test "update individual datastream interface" do
    assert Engine.install_interface("autotestrealm", @test_draft_interface_c_0) == :ok

    assert unpack_source(
             Engine.interface_source("autotestrealm", "com.ispirata.TestDatastream", 0)
           ) == unpack_source({:ok, @test_draft_interface_c_0})

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.TestDatastream"]}

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.TestDatastream") ==
             {:ok, [[major_version: 0, minor_version: 10]]}

    assert Engine.update_interface("autotestrealm", @test_draft_interface_c_1) == :ok

    assert unpack_source(
             Engine.interface_source("autotestrealm", "com.ispirata.TestDatastream", 0)
           ) == unpack_source({:ok, @test_draft_interface_c_1})

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.TestDatastream"]}

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.TestDatastream") ==
             {:ok, [[major_version: 0, minor_version: 15]]}
  end

  test "update explicit timestamp, doc, description, expiry and retention for individual datastream interface" do
    assert Engine.install_interface("autotestrealm", @test_interface_d_0) == :ok

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["org.astarte-platform.Values"]}

    assert Engine.list_interface_versions("autotestrealm", "org.astarte-platform.Values") ==
             {:ok, [[major_version: 1, minor_version: 0]]}

    assert Engine.update_interface("autotestrealm", @test_interface_d_1) == :ok

    {:ok, updated_interface} =
      unpack_source(Engine.interface_source("autotestrealm", "org.astarte-platform.Values", 1))

    assert {:ok, ^updated_interface} = unpack_source({:ok, @test_interface_d_1})

    assert Engine.list_interface_versions("autotestrealm", "org.astarte-platform.Values") ==
             {:ok, [[major_version: 1, minor_version: 1]]}

    assert Engine.update_interface("autotestrealm", @test_interface_d_incompatible_change) ==
             {:error, :incompatible_endpoint_change}
  end

  test "update object aggregated interface adding an endpoint" do
    assert Engine.install_interface("autotestrealm", @test_draft_interface_b_0) == :ok

    assert unpack_source(Engine.interface_source("autotestrealm", "com.ObjectAggregation", 0)) ==
             unpack_source({:ok, @test_draft_interface_b_0})

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ObjectAggregation"]}

    assert Engine.list_interface_versions("autotestrealm", "com.ObjectAggregation") ==
             {:ok, [[major_version: 0, minor_version: 3]]}

    assert Engine.update_interface("autotestrealm", @test_draft_interface_b_1) == :ok

    assert unpack_source(Engine.interface_source("autotestrealm", "com.ObjectAggregation", 0)) ==
             unpack_source({:ok, @test_draft_interface_b_1})

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ObjectAggregation"]}

    assert Engine.list_interface_versions("autotestrealm", "com.ObjectAggregation") ==
             {:ok, [[major_version: 0, minor_version: 4]]}

    assert Engine.delete_interface("autotestrealm", "com.ObjectAggregation", 0) == :ok

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, []}
  end

  test "update explicit timestamp, doc, description, expiry and retention for object datastream interface" do
    assert Engine.install_interface("autotestrealm", @test_interface_e_0) == :ok

    assert Engine.get_interfaces_list("autotestrealm") ==
             {:ok, ["com.autotest.AggregateValuesUpdate"]}

    assert Engine.list_interface_versions("autotestrealm", "com.autotest.AggregateValuesUpdate") ==
             {:ok, [[major_version: 1, minor_version: 0]]}

    assert Engine.update_interface("autotestrealm", @test_interface_e_1) == :ok

    {:ok, updated_interface} =
      unpack_source(
        Engine.interface_source("autotestrealm", "com.autotest.AggregateValuesUpdate", 1)
      )

    assert {:ok, ^updated_interface} = unpack_source({:ok, @test_interface_e_1})

    assert Engine.list_interface_versions("autotestrealm", "com.autotest.AggregateValuesUpdate") ==
             {:ok, [[major_version: 1, minor_version: 1]]}

    assert Engine.update_interface("autotestrealm", @test_interface_e_incompatible_change) ==
             {:error, :invalid_interface_document}
  end

  test "update a mapping and add an endpoint in one shot for object datastream interface" do
    assert Engine.install_interface("autotestrealm", @test_interface_f_0) == :ok

    assert Engine.get_interfaces_list("autotestrealm") ==
             {:ok, ["com.autotest.AggregateValuesUpdateAndAdd"]}

    assert Engine.list_interface_versions(
             "autotestrealm",
             "com.autotest.AggregateValuesUpdateAndAdd"
           ) ==
             {:ok, [[major_version: 1, minor_version: 0]]}

    assert Engine.update_interface("autotestrealm", @test_interface_f_1) == :ok

    {:ok, updated_interface} =
      unpack_source(
        Engine.interface_source("autotestrealm", "com.autotest.AggregateValuesUpdateAndAdd", 1)
      )

    assert {:ok, ^updated_interface} = unpack_source({:ok, @test_interface_f_1})

    assert Engine.list_interface_versions(
             "autotestrealm",
             "com.autotest.AggregateValuesUpdateAndAdd"
           ) ==
             {:ok, [[major_version: 1, minor_version: 1]]}
  end

  test "fail update missing interface" do
    assert Engine.update_interface("autotestrealm", @test_draft_interface_b_1) ==
             {:error, :interface_major_version_does_not_exist}

    assert Engine.update_interface("autotestrealm", @test_draft_interface_c_1) ==
             {:error, :interface_major_version_does_not_exist}
  end

  test "fail update with less mappings" do
    assert Engine.install_interface("autotestrealm", @test_draft_interface_c_0) == :ok

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.TestDatastream"]}

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.TestDatastream") ==
             {:ok, [[major_version: 0, minor_version: 10]]}

    assert Engine.update_interface("autotestrealm", @test_draft_interface_c_wrong_update) ==
             {:error, :missing_endpoints}

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.TestDatastream"]}

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.TestDatastream") ==
             {:ok, [[major_version: 0, minor_version: 10]]}

    assert Engine.update_interface("autotestrealm", @test_draft_interface_c_1) == :ok

    assert unpack_source(
             Engine.interface_source("autotestrealm", "com.ispirata.TestDatastream", 0)
           ) == unpack_source({:ok, @test_draft_interface_c_1})

    assert Engine.install_interface("autotestrealm", @test_draft_interface_c_wrong_update) ==
             {:error, :already_installed_interface}

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.TestDatastream"]}

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.TestDatastream") ==
             {:ok, [[major_version: 0, minor_version: 15]]}
  end

  test "fail on interface type change" do
    assert Engine.install_interface("autotestrealm", @test_draft_interface_c_0) == :ok

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.TestDatastream"]}

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.TestDatastream") ==
             {:ok, [[major_version: 0, minor_version: 10]]}

    assert Engine.update_interface("autotestrealm", @test_draft_interface_c_invalid_change) ==
             {:error, :invalid_update}

    assert unpack_source(
             Engine.interface_source("autotestrealm", "com.ispirata.TestDatastream", 0)
           ) == unpack_source({:ok, @test_draft_interface_c_0})

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.TestDatastream"]}

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.TestDatastream") ==
             {:ok, [[major_version: 0, minor_version: 10]]}
  end

  test "fail on mapping incompatible change" do
    assert Engine.install_interface("autotestrealm", @test_draft_interface_c_0) == :ok

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.TestDatastream"]}

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.TestDatastream") ==
             {:ok, [[major_version: 0, minor_version: 10]]}

    assert Engine.update_interface("autotestrealm", @test_draft_interface_c_incompatible_change) ==
             {:error, :incompatible_endpoint_change}

    assert unpack_source(
             Engine.interface_source("autotestrealm", "com.ispirata.TestDatastream", 0)
           ) == unpack_source({:ok, @test_draft_interface_c_0})

    assert Engine.get_interfaces_list("autotestrealm") == {:ok, ["com.ispirata.TestDatastream"]}

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.TestDatastream") ==
             {:ok, [[major_version: 0, minor_version: 10]]}
  end

  test "fail on interface downgrade" do
    assert Engine.install_interface("autotestrealm", @test_draft_interface_c_0) == :ok

    assert unpack_source(
             Engine.interface_source("autotestrealm", "com.ispirata.TestDatastream", 0)
           ) == unpack_source({:ok, @test_draft_interface_c_0})

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.TestDatastream") ==
             {:ok, [[major_version: 0, minor_version: 10]]}

    assert Engine.update_interface("autotestrealm", @test_draft_interface_c_1) == :ok

    assert unpack_source(
             Engine.interface_source("autotestrealm", "com.ispirata.TestDatastream", 0)
           ) == unpack_source({:ok, @test_draft_interface_c_1})

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.TestDatastream") ==
             {:ok, [[major_version: 0, minor_version: 15]]}

    assert Engine.update_interface("autotestrealm", @test_draft_interface_c_downgrade) ==
             {:error, :downgrade_not_allowed}

    assert unpack_source(
             Engine.interface_source("autotestrealm", "com.ispirata.TestDatastream", 0)
           ) == unpack_source({:ok, @test_draft_interface_c_1})

    assert Engine.list_interface_versions("autotestrealm", "com.ispirata.TestDatastream") ==
             {:ok, [[major_version: 0, minor_version: 15]]}
  end

  test "get JWT public key PEM with existing realm" do
    assert Engine.get_jwt_public_key_pem("autotestrealm") ==
             {:ok, DatabaseTestHelper.jwt_public_key_pem_fixture()}
  end

  test "get JWT public key PEM with unexisting realm" do
    assert Engine.get_jwt_public_key_pem("notexisting") == {:error, :realm_not_found}
  end

  test "update JWT public key PEM" do
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

  test "install HTTP trigger" do
    trigger_name = "http_trigger"

    action = """
    {
      "http_url": "http://hello.world.ai",
      "http_method": "post",
      "ignore_ssl_errors": true
    }
    """

    assert {:ok, []} = Engine.get_triggers_list(@test_realm_name)

    assert :ok = Engine.install_trigger(@test_realm_name, trigger_name, nil, action, [])

    assert {:ok, [^trigger_name]} = Engine.get_triggers_list(@test_realm_name)
  end

  test "install AMQP trigger" do
    trigger_name = "amqp_trigger"

    action = """
    {
      "amqp_exchange": "astarte_events_test_hello_world",
      "amqp_routing_key": "my_routing_key",
      "amqp_message_expiration_ms": 10000,
      "amqp_message_persistent": false
    }
    """

    assert :ok = Engine.install_trigger(@test_realm_name, trigger_name, nil, action, [])
  end

  test "delete trigger" do
    trigger_name = "http_trigger"

    action = """
    {
      "http_url": "http://hello.world.ai",
      "http_method": "post"
    }
    """

    # Just to make sure a trigger exists
    _ = Engine.install_trigger(@test_realm_name, trigger_name, nil, action, [])

    assert {:ok, [^trigger_name]} = Engine.get_triggers_list(@test_realm_name)

    assert :ok = Engine.delete_trigger(@test_realm_name, trigger_name)

    assert {:ok, []} = Engine.get_triggers_list(@test_realm_name)
  end

  test "fail install when trigger already exists" do
    trigger_name = "a_trigger"

    action = """
    {
      "amqp_exchange": "astarte_events_test_hello_world",
      "amqp_routing_key": "my_routing_key",
      "amqp_message_expiration_ms": 10000,
      "amqp_message_persistent": false
    }
    """

    assert :ok = Engine.install_trigger(@test_realm_name, trigger_name, nil, action, [])

    assert {:error, :already_installed_trigger} =
             Engine.install_trigger(@test_realm_name, trigger_name, nil, action, [])
  end

  test "fail to install trigger on missing interface" do
    trigger_name = "http_trigger_missing_iface"

    action = """
    {
      "http_url": "http://hello.world.ai",
      "http_method": "post"
    }
    """

    serialized_simple_triggers =
      [
        %SimpleTriggerConfig{
          type: "data_trigger",
          on: "incoming_data",
          interface_name: "com.ispirata.TestMissing",
          interface_major: 0,
          match_path: "/streamTest/value",
          value_match_operator: "*"
        }
      ]
      |> serialize_simple_triggers()

    assert {:error, :interface_not_found} =
             Engine.install_trigger(
               @test_realm_name,
               trigger_name,
               nil,
               action,
               serialized_simple_triggers
             )
  end

  test "fail to install property trigger on datastream interface" do
    # Just to make sure a datastream interface is installed
    _ = Engine.install_interface(@test_realm_name, @test_draft_interface_c_0)

    trigger_name = "property_trigger"

    action = """
    {
      "http_url": "http://hello.world.ai",
      "http_method": "post"
    }
    """

    serialized_simple_triggers =
      [
        %SimpleTriggerConfig{
          type: "data_trigger",
          on: "value_change",
          interface_name: "com.ispirata.TestDatastream",
          interface_major: 0,
          match_path: "/*",
          value_match_operator: "*"
        }
      ]
      |> serialize_simple_triggers()

    assert {:error, :invalid_datastream_trigger} =
             Engine.install_trigger(
               @test_realm_name,
               trigger_name,
               nil,
               action,
               serialized_simple_triggers
             )
  end

  test "fail to install value change trigger on all paths" do
    # Just to make sure a datastream interface is installed
    _ = Engine.install_interface(@test_realm_name, @test_interface_a_2)

    trigger_name = "invalid_value_change_trigger"

    action = """
    {
      "http_url": "http://hello.world.ai",
      "http_method": "post"
    }
    """

    serialized_simple_triggers =
      [
        %SimpleTriggerConfig{
          type: "data_trigger",
          on: "value_change",
          interface_name: "com.ispirata.Hemera.DeviceLog.Status",
          interface_major: 2,
          match_path: "/*"
        }
      ]
      |> serialize_simple_triggers()

    assert {:error, :unsupported_trigger_type} =
             Engine.install_trigger(
               @test_realm_name,
               trigger_name,
               nil,
               action,
               serialized_simple_triggers
             )
  end

  test "fail to install trigger not supported by object-aggregated interface" do
    # Just to make sure an object-aggregated interface is installed
    :ok = Engine.install_interface("autotestrealm", @test_draft_interface_g_0)

    trigger_name = "not_supported_trigger"

    action = """
    {
      "http_url": "http://hello.world.ai",
      "http_method": "post"
    }
    """

    serialized_simple_triggers =
      [
        %SimpleTriggerConfig{
          type: "data_trigger",
          on: "value_stored",
          interface_name: "com.astarte.ObjectAggregationIface",
          interface_major: 0,
          match_path: "/test/realValues",
          value_match_operator: "*"
        }
      ]
      |> serialize_simple_triggers()

    assert {:error, :invalid_object_aggregation_trigger} =
             Engine.install_trigger(
               @test_realm_name,
               trigger_name,
               nil,
               action,
               serialized_simple_triggers
             )
  end

  test "fail to delete missing trigger" do
    trigger_name = "missing_trigger"

    assert {:error, :trigger_not_found} = Engine.delete_trigger(@test_realm_name, trigger_name)
  end

  test "install trigger policy" do
    assert Engine.get_trigger_policies_list("autotestrealm") == {:ok, []}

    assert Engine.install_trigger_policy("autotestrealm", @test_trigger_policy_1) == :ok
    assert Engine.install_trigger_policy("autotestrealm", @test_trigger_policy_2) == :ok

    # can't install again the same policy
    assert Engine.install_trigger_policy("autotestrealm", @test_trigger_policy_1) ==
             {:error, :trigger_policy_already_present}

    assert Engine.delete_trigger_policy("autotestrealm", "aname") == :ok

    assert Engine.get_trigger_policies_list("autotestrealm") == {:ok, ["anothername"]}

    assert Engine.install_trigger_policy("autotestrealm", @test_trigger_policy_1) == :ok

    {:ok, policies_list} = Engine.get_trigger_policies_list("autotestrealm")

    sorted_policies =
      policies_list
      |> Enum.sort()

    assert sorted_policies == ["aname", "anothername"]
  end

  test "trigger and policy installation coherence" do
    assert Engine.install_trigger_policy("autotestrealm", @test_trigger_policy_1) == :ok

    trigger = %{
      realm_name: "autotestrealm",
      name: "test_trigger",
      policy: "aname",
      action: Jason.encode!(%{}),
      simple_triggers: []
    }

    assert Engine.install_trigger(
             trigger.realm_name,
             trigger.name,
             trigger.policy,
             trigger.action,
             trigger.simple_triggers
           ) == :ok

    assert Engine.delete_trigger(trigger.realm_name, trigger.name) == :ok

    assert Engine.delete_trigger_policy("autotestrealm", "aname") == :ok
  end

  test "trigger with non existant policy fails" do
    trigger = %{
      realm_name: "autotestrealm",
      name: "test_trigger",
      policy: "idontexist",
      action: Jason.encode!(%{}),
      simple_triggers: []
    }

    assert {:error, :trigger_policy_not_found} =
             Engine.install_trigger(
               trigger.realm_name,
               trigger.name,
               trigger.policy,
               trigger.action,
               trigger.simple_triggers
             )
  end

  test "trigger with nil policy succeeds" do
    trigger = %{
      realm_name: "autotestrealm",
      name: "test_trigger",
      policy: nil,
      action: Jason.encode!(%{}),
      simple_triggers: []
    }

    assert Engine.install_trigger(
             trigger.realm_name,
             trigger.name,
             trigger.policy,
             trigger.action,
             trigger.simple_triggers
           ) == :ok
  end

  test "begin deletion of an existing device" do
    device_id = Device.random_device_id()
    encoded_device_id = Device.encode_device_id(device_id)
    DatabaseTestHelper.seed_devices_test_data!(realm_name: "autotestrealm", device_id: device_id)

    assert :ok = Engine.delete_device(@test_realm_name, encoded_device_id)

    statement = """
    SELECT * FROM #{@test_realm_name}.deletion_in_progress
    """

    assert [%{device_id: ^device_id}] =
             Xandra.Cluster.execute!(:xandra, statement, %{}, uuid_format: :binary)
             |> Enum.to_list()
  end

  test "do not begin deletion of a missing device" do
    missing_device_id = Device.random_device_id() |> Device.encode_device_id()

    assert {:error, :device_not_found} = Engine.delete_device(@test_realm_name, missing_device_id)
  end

  test "retrieve device registration limit for an existing realm" do
    limit = 10
    realm_name = "autotestrealm"

    DatabaseTestHelper.seed_realm_test_data!(
      realm_name: realm_name,
      device_registration_limit: limit
    )

    assert {:ok, ^limit} = Engine.get_device_registration_limit(realm_name)
  end

  test "fail to retrieve device registration limit if realm does not exist" do
    realm_name = "realm#{System.unique_integer([:positive])}"
    assert {:error, :realm_not_found} = Engine.get_device_registration_limit(realm_name)
  end

  defp unpack_source({:ok, source}) when is_binary(source) do
    interface_obj = Jason.decode!(source)

    mappings =
      interface_obj["mappings"]
      |> Enum.sort()

    new_obj = Map.put(interface_obj, "mappings", mappings)

    {:ok, new_obj}
  end

  defp unpack_source(any) do
    any
  end

  defp serialize_simple_triggers(simple_triggers) do
    simple_triggers
    |> Enum.map(&SimpleTriggerConfig.to_tagged_simple_trigger/1)
    |> Enum.map(&TaggedSimpleTrigger.encode/1)
  end
end
