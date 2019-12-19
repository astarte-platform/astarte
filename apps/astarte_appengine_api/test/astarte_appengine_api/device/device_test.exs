#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.AppEngine.API.DeviceTest do
  use ExUnit.Case
  alias Astarte.AppEngine.API.DatabaseTestHelper
  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.AppEngine.API.Device.InterfaceVersion
  alias Astarte.DataAccess.Database
  alias CQEx.Query, as: DatabaseQuery

  @expected_introspection %{
    "com.example.PixelsConfiguration" => %InterfaceVersion{major: 1, minor: 0},
    "com.example.TestObject" => %InterfaceVersion{major: 1, minor: 5},
    "com.test.LCDMonitor" => %InterfaceVersion{major: 1, minor: 3},
    "com.test.SimpleStreamTest" => %InterfaceVersion{major: 1, minor: 0}
  }

  @expected_device_status %DeviceStatus{
    connected: false,
    id: "f0VMRgIBAQAAAAAAAAAAAA",
    aliases: %{"display_name" => "device_a"},
    introspection: @expected_introspection,
    last_connection: %DateTime{
      calendar: Calendar.ISO,
      microsecond: {0, 3},
      second: 0,
      std_offset: 0,
      time_zone: "Etc/UTC",
      utc_offset: 0,
      zone_abbr: "UTC",
      day: 28,
      hour: 3,
      minute: 45,
      month: 9,
      year: 2017
    },
    last_disconnection: %DateTime{
      calendar: Calendar.ISO,
      microsecond: {0, 3},
      month: 9,
      second: 0,
      std_offset: 0,
      time_zone: "Etc/UTC",
      utc_offset: 0,
      year: 2017,
      zone_abbr: "UTC",
      day: 29,
      hour: 18,
      minute: 25
    },
    first_registration: %DateTime{
      calendar: Calendar.ISO,
      microsecond: {0, 3},
      second: 0,
      std_offset: 0,
      time_zone: "Etc/UTC",
      utc_offset: 0,
      zone_abbr: "UTC",
      day: 15,
      hour: 9,
      minute: 44,
      month: 8,
      year: 2016
    },
    first_credentials_request: %DateTime{
      calendar: Calendar.ISO,
      microsecond: {0, 3},
      second: 0,
      std_offset: 0,
      time_zone: "Etc/UTC",
      utc_offset: 0,
      zone_abbr: "UTC",
      day: 20,
      hour: 9,
      minute: 44,
      month: 8,
      year: 2016
    },
    last_credentials_request_ip: "198.51.100.89",
    last_seen_ip: "198.51.100.81",
    total_received_bytes: 4_500_000,
    total_received_msgs: 45000
  }

  setup do
    DatabaseTestHelper.seed_data()
  end

  setup_all do
    {:ok, _client} = DatabaseTestHelper.create_test_keyspace()

    on_exit(fn ->
      DatabaseTestHelper.destroy_local_test_keyspace()
    end)

    :ok
  end

  test "list_interfaces/2 returns all interfaces" do
    {:ok, result} = Device.list_interfaces("autotestrealm", "f0VMRgIBAQAAAAAAAAAAAA")

    assert Enum.sort(result) == [
             "com.example.PixelsConfiguration",
             "com.example.TestObject",
             "com.test.LCDMonitor",
             "com.test.SimpleStreamTest"
           ]
  end

  test "list_interfaces/2 returns [] on a device without introspection" do
    encoded_device_id = "9ovH-plr6J_JPGWIp7c29w"
    {:ok, client} = DatabaseTestHelper.connect_to_test_keyspace()
    {:ok, device_id} = Astarte.Core.Device.decode_device_id(encoded_device_id)
    DatabaseTestHelper.insert_empty_device(client, device_id)

    assert Device.list_interfaces("autotestrealm", encoded_device_id) == {:ok, []}

    DatabaseTestHelper.remove_device(client, device_id)
  end

  test "get_interface_values! returns interfaces values on individual property interface" do
    expected_reply = %{
      "time" => %{"from" => 8, "to" => 20},
      "lcdCommand" => "SWITCH_ON",
      "weekSchedule" => %{
        "2" => %{"start" => 12, "stop" => 15},
        "3" => %{"start" => 15, "stop" => 16},
        "4" => %{"start" => 16, "stop" => 18}
      }
    }

    assert unpack_interface_values(
             Device.get_interface_values!(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               "com.test.LCDMonitor",
               %{}
             )
           ) == expected_reply

    assert unpack_interface_values(
             Device.get_interface_values!(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               "com.test.LCDMonitor",
               "time",
               %{}
             )
           ) == %{"from" => 8, "to" => 20}

    assert unpack_interface_values(
             Device.get_interface_values!(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               "com.test.LCDMonitor",
               "time/from",
               %{}
             )
           ) == 8

    assert Device.get_interface_values!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAQ",
             "com.test.LCDMonitor",
             "time/from",
             %{}
           ) == {:error, :device_not_found}

    assert Device.get_interface_values!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             "com.test.Missing",
             "weekSchedule/3/start",
             %{}
           ) == {:error, :interface_not_in_introspection}

    assert Device.get_interface_values!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             "com.test.LCDMonitor",
             "time/missing",
             %{}
           ) == {:error, :endpoint_not_found}

    assert Device.get_interface_values!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             "com.test.LCDMonitor",
             "weekSchedule/9/start",
             %{}
           ) == {:error, :path_not_found}

    assert Device.get_interface_values!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             "com.test.LCDMonitor",
             "weekSchedule/9",
             %{}
           ) == {:error, :path_not_found}
  end

  test "get_interface_values! returns interfaces values on individual datastream interface" do
    expected_reply = [
      %{
        "timestamp" => %DateTime{
          calendar: Calendar.ISO,
          day: 28,
          hour: 4,
          microsecond: {0, 3},
          minute: 5,
          month: 9,
          second: 0,
          std_offset: 0,
          time_zone: "Etc/UTC",
          utc_offset: 0,
          year: 2017,
          zone_abbr: "UTC"
        },
        "value" => 0
      },
      %{
        "timestamp" => %DateTime{
          calendar: Calendar.ISO,
          day: 28,
          hour: 4,
          microsecond: {0, 3},
          minute: 6,
          month: 9,
          second: 0,
          std_offset: 0,
          time_zone: "Etc/UTC",
          utc_offset: 0,
          year: 2017,
          zone_abbr: "UTC"
        },
        "value" => 1
      },
      %{
        "timestamp" => %DateTime{
          calendar: Calendar.ISO,
          day: 28,
          hour: 4,
          microsecond: {0, 3},
          minute: 7,
          month: 9,
          second: 0,
          std_offset: 0,
          time_zone: "Etc/UTC",
          utc_offset: 0,
          year: 2017,
          zone_abbr: "UTC"
        },
        "value" => 2
      },
      %{
        "timestamp" => %DateTime{
          calendar: Calendar.ISO,
          day: 29,
          hour: 5,
          microsecond: {0, 3},
          minute: 7,
          month: 9,
          second: 0,
          std_offset: 0,
          time_zone: "Etc/UTC",
          utc_offset: 0,
          year: 2017,
          zone_abbr: "UTC"
        },
        "value" => 3
      },
      %{
        "timestamp" => %DateTime{
          calendar: Calendar.ISO,
          day: 30,
          hour: 7,
          microsecond: {0, 3},
          minute: 10,
          month: 9,
          second: 0,
          std_offset: 0,
          time_zone: "Etc/UTC",
          utc_offset: 0,
          year: 2017,
          zone_abbr: "UTC"
        },
        "value" => 4
      }
    ]

    assert unpack_interface_values(
             Device.get_interface_values!(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               "com.test.SimpleStreamTest",
               "0/value",
               %{}
             )
           ) == expected_reply

    expected_reply = [
      %{
        "timestamp" => %DateTime{
          calendar: Calendar.ISO,
          day: 30,
          hour: 7,
          microsecond: {0, 3},
          minute: 10,
          month: 9,
          second: 0,
          std_offset: 0,
          time_zone: "Etc/UTC",
          utc_offset: 0,
          year: 2017,
          zone_abbr: "UTC"
        },
        "value" => 4
      },
      %{
        "timestamp" => %DateTime{
          calendar: Calendar.ISO,
          day: 29,
          hour: 5,
          microsecond: {0, 3},
          minute: 7,
          month: 9,
          second: 0,
          std_offset: 0,
          time_zone: "Etc/UTC",
          utc_offset: 0,
          year: 2017,
          zone_abbr: "UTC"
        },
        "value" => 3
      }
    ]

    assert unpack_interface_values(
             Device.get_interface_values!(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               "com.test.SimpleStreamTest",
               "0/value",
               %{"limit" => 2}
             )
           ) == expected_reply

    expected_reply = [
      %{
        "timestamp" => %DateTime{
          calendar: Calendar.ISO,
          day: 28,
          hour: 4,
          microsecond: {0, 3},
          minute: 6,
          month: 9,
          second: 0,
          std_offset: 0,
          time_zone: "Etc/UTC",
          utc_offset: 0,
          year: 2017,
          zone_abbr: "UTC"
        },
        "value" => 1
      },
      %{
        "timestamp" => %DateTime{
          calendar: Calendar.ISO,
          day: 28,
          hour: 4,
          microsecond: {0, 3},
          minute: 7,
          month: 9,
          second: 0,
          std_offset: 0,
          time_zone: "Etc/UTC",
          utc_offset: 0,
          year: 2017,
          zone_abbr: "UTC"
        },
        "value" => 2
      },
      %{
        "timestamp" => %DateTime{
          calendar: Calendar.ISO,
          day: 29,
          hour: 5,
          microsecond: {0, 3},
          minute: 7,
          month: 9,
          second: 0,
          std_offset: 0,
          time_zone: "Etc/UTC",
          utc_offset: 0,
          year: 2017,
          zone_abbr: "UTC"
        },
        "value" => 3
      }
    ]

    opts = %{"since" => "2017-09-28T04:06:00.000Z", "to" => "2017-09-30T07:10:00.000Z"}

    assert unpack_interface_values(
             Device.get_interface_values!(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               "com.test.SimpleStreamTest",
               "0/value",
               opts
             )
           ) == expected_reply

    expected_reply = [
      %{
        "timestamp" => %DateTime{
          calendar: Calendar.ISO,
          day: 28,
          hour: 4,
          microsecond: {0, 3},
          minute: 6,
          month: 9,
          second: 0,
          std_offset: 0,
          time_zone: "Etc/UTC",
          utc_offset: 0,
          year: 2017,
          zone_abbr: "UTC"
        },
        "value" => 1
      },
      %{
        "timestamp" => %DateTime{
          calendar: Calendar.ISO,
          day: 28,
          hour: 4,
          microsecond: {0, 3},
          minute: 7,
          month: 9,
          second: 0,
          std_offset: 0,
          time_zone: "Etc/UTC",
          utc_offset: 0,
          year: 2017,
          zone_abbr: "UTC"
        },
        "value" => 2
      }
    ]

    opts = %{
      "since" => "2017-09-28T04:06:00.000Z",
      "to" => "2017-09-30T07:10:00.000Z",
      "limit" => 2
    }

    assert unpack_interface_values(
             Device.get_interface_values!(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               "com.test.SimpleStreamTest",
               "0/value",
               opts
             )
           ) == expected_reply

    expected_reply = [
      %{
        "timestamp" => %DateTime{
          calendar: Calendar.ISO,
          day: 28,
          hour: 4,
          microsecond: {0, 3},
          minute: 7,
          month: 9,
          second: 0,
          std_offset: 0,
          time_zone: "Etc/UTC",
          utc_offset: 0,
          year: 2017,
          zone_abbr: "UTC"
        },
        "value" => 2
      }
    ]

    opts = %{
      "since_after" => "2017-09-28T04:06:00.000Z",
      "to" => "2017-09-30T07:10:00.000Z",
      "limit" => 1
    }

    assert unpack_interface_values(
             Device.get_interface_values!(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               "com.test.SimpleStreamTest",
               "0/value",
               opts
             )
           ) == expected_reply

    # format option tests

    expected_reply = {
      :ok,
      %Astarte.AppEngine.API.Device.InterfaceValues{
        metadata: %{
          "columns" => %{"timestamp" => 0, "value" => 1},
          "table_header" => ["timestamp", "value"]
        },
        data: [
          [
            %DateTime{
              calendar: Calendar.ISO,
              day: 28,
              hour: 4,
              microsecond: {0, 3},
              minute: 5,
              month: 9,
              second: 0,
              std_offset: 0,
              time_zone: "Etc/UTC",
              utc_offset: 0,
              year: 2017,
              zone_abbr: "UTC"
            },
            0
          ],
          [
            %DateTime{
              calendar: Calendar.ISO,
              day: 28,
              hour: 4,
              microsecond: {0, 3},
              minute: 6,
              month: 9,
              second: 0,
              std_offset: 0,
              time_zone: "Etc/UTC",
              utc_offset: 0,
              year: 2017,
              zone_abbr: "UTC"
            },
            1
          ],
          [
            %DateTime{
              calendar: Calendar.ISO,
              day: 28,
              hour: 4,
              microsecond: {0, 3},
              minute: 7,
              month: 9,
              second: 0,
              std_offset: 0,
              time_zone: "Etc/UTC",
              utc_offset: 0,
              year: 2017,
              zone_abbr: "UTC"
            },
            2
          ],
          [
            %DateTime{
              calendar: Calendar.ISO,
              day: 29,
              hour: 5,
              microsecond: {0, 3},
              minute: 7,
              month: 9,
              second: 0,
              std_offset: 0,
              time_zone: "Etc/UTC",
              utc_offset: 0,
              year: 2017,
              zone_abbr: "UTC"
            },
            3
          ],
          [
            %DateTime{
              calendar: Calendar.ISO,
              day: 30,
              hour: 7,
              microsecond: {0, 3},
              minute: 10,
              month: 9,
              second: 0,
              std_offset: 0,
              time_zone: "Etc/UTC",
              utc_offset: 0,
              year: 2017,
              zone_abbr: "UTC"
            },
            4
          ]
        ]
      }
    }

    opts = %{"format" => "table"}

    assert Device.get_interface_values!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             "com.test.SimpleStreamTest",
             "0/value",
             opts
           ) == expected_reply

    expected_reply = %{
      "value" => [
        [
          0,
          %DateTime{
            calendar: Calendar.ISO,
            day: 28,
            hour: 4,
            microsecond: {0, 3},
            minute: 5,
            month: 9,
            second: 0,
            std_offset: 0,
            time_zone: "Etc/UTC",
            utc_offset: 0,
            year: 2017,
            zone_abbr: "UTC"
          }
        ],
        [
          1,
          %DateTime{
            calendar: Calendar.ISO,
            day: 28,
            hour: 4,
            microsecond: {0, 3},
            minute: 6,
            month: 9,
            second: 0,
            std_offset: 0,
            time_zone: "Etc/UTC",
            utc_offset: 0,
            year: 2017,
            zone_abbr: "UTC"
          }
        ],
        [
          2,
          %DateTime{
            calendar: Calendar.ISO,
            day: 28,
            hour: 4,
            microsecond: {0, 3},
            minute: 7,
            month: 9,
            second: 0,
            std_offset: 0,
            time_zone: "Etc/UTC",
            utc_offset: 0,
            year: 2017,
            zone_abbr: "UTC"
          }
        ],
        [
          3,
          %DateTime{
            calendar: Calendar.ISO,
            day: 29,
            hour: 5,
            microsecond: {0, 3},
            minute: 7,
            month: 9,
            second: 0,
            std_offset: 0,
            time_zone: "Etc/UTC",
            utc_offset: 0,
            year: 2017,
            zone_abbr: "UTC"
          }
        ],
        [
          4,
          %DateTime{
            calendar: Calendar.ISO,
            day: 30,
            hour: 7,
            microsecond: {0, 3},
            minute: 10,
            month: 9,
            second: 0,
            std_offset: 0,
            time_zone: "Etc/UTC",
            utc_offset: 0,
            year: 2017,
            zone_abbr: "UTC"
          }
        ]
      ]
    }

    opts = %{"format" => "disjoint_tables"}

    assert unpack_interface_values(
             Device.get_interface_values!(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               "com.test.SimpleStreamTest",
               "0/value",
               opts
             )
           ) == expected_reply

    # exception tests

    assert Device.get_interface_values!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAQ",
             "com.test.SimpleStreamTest",
             "0/value",
             %{}
           ) == {:error, :device_not_found}

    assert Device.get_interface_values!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             "com.test.Missing",
             "0/value",
             %{}
           ) == {:error, :interface_not_in_introspection}

    assert Device.get_interface_values!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             "com.test.SimpleStreamTest",
             "missing/endpoint/test",
             %{}
           ) == {:error, :endpoint_not_found}

    assert Device.get_interface_values!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             "com.test.SimpleStreamTest",
             "100/value",
             %{}
           ) == {:error, :path_not_found}
  end

  test "get_interface_values! returns interfaces values on object datastream interface" do
    test = "autotestrealm"
    device_id = "f0VMRgIBAQAAAAAAAAAAAA"

    expected_reply = [
      %{
        "string" => "aaa",
        "value" => 1.1,
        "timestamp" => elem(DateTime.from_iso8601("2017-09-30 07:10:00.000Z"), 1)
      },
      %{
        "string" => "bbb",
        "value" => 2.2,
        "timestamp" => elem(DateTime.from_iso8601("2017-09-30 07:12:00.000Z"), 1)
      },
      %{
        "string" => "ccc",
        "value" => 3.3,
        "timestamp" => elem(DateTime.from_iso8601("2017-09-30 07:13:00.000Z"), 1)
      }
    ]

    assert unpack_interface_values(
             Device.get_interface_values!(test, device_id, "com.example.TestObject", %{})
           ) == expected_reply

    expected_reply = [
      %{
        "string" => "bbb",
        "value" => 2.2,
        "timestamp" => elem(DateTime.from_iso8601("2017-09-30 07:12:00.000Z"), 1)
      },
      %{
        "string" => "ccc",
        "value" => 3.3,
        "timestamp" => elem(DateTime.from_iso8601("2017-09-30 07:13:00.000Z"), 1)
      }
    ]

    opts = %{"since" => "2017-09-30 07:12:00.000Z"}

    assert unpack_interface_values(
             Device.get_interface_values!(test, device_id, "com.example.TestObject", opts)
           ) == expected_reply

    expected_reply = [
      %{
        "string" => "ccc",
        "value" => 3.3,
        "timestamp" => elem(DateTime.from_iso8601("2017-09-30 07:13:00.000Z"), 1)
      }
    ]

    opts = %{"since_after" => "2017-09-30 07:12:00.000Z"}

    assert unpack_interface_values(
             Device.get_interface_values!(test, device_id, "com.example.TestObject", opts)
           ) == expected_reply

    expected_reply = [
      %{
        "string" => "ccc",
        "value" => 3.3,
        "timestamp" => elem(DateTime.from_iso8601("2017-09-30 07:13:00.000Z"), 1)
      },
      %{
        "string" => "bbb",
        "value" => 2.2,
        "timestamp" => elem(DateTime.from_iso8601("2017-09-30 07:12:00.000Z"), 1)
      }
    ]

    opts = %{"limit" => 2}

    assert unpack_interface_values(
             Device.get_interface_values!(test, device_id, "com.example.TestObject", opts)
           ) == expected_reply

    expected_reply = [
      %{
        "string" => "bbb",
        "value" => 2.2,
        "timestamp" => elem(DateTime.from_iso8601("2017-09-30 07:12:00.000Z"), 1)
      }
    ]

    opts = %{"since" => "2017-09-30 07:12:00.000Z", "to" => "2017-09-30 07:13:00.000Z"}

    assert unpack_interface_values(
             Device.get_interface_values!(test, device_id, "com.example.TestObject", opts)
           ) == expected_reply

    opts = %{"since" => "2017-09-30 07:12:00.000Z", "limit" => 1}

    assert unpack_interface_values(
             Device.get_interface_values!(test, device_id, "com.example.TestObject", opts)
           ) == expected_reply

    # format option tests

    expected_reply = {
      :ok,
      %Astarte.AppEngine.API.Device.InterfaceValues{
        data: [
          [elem(DateTime.from_iso8601("2017-09-30 07:10:00.000Z"), 1), 1.1, "aaa"],
          [elem(DateTime.from_iso8601("2017-09-30 07:12:00.000Z"), 1), 2.2, "bbb"],
          [elem(DateTime.from_iso8601("2017-09-30 07:13:00.000Z"), 1), 3.3, "ccc"]
        ],
        metadata: %{
          "columns" => %{"string" => 2, "timestamp" => 0, "value" => 1},
          "table_header" => ["timestamp", "value", "string"]
        }
      }
    }

    opts = %{"format" => "table"}

    assert Device.get_interface_values!(test, device_id, "com.example.TestObject", opts) ==
             expected_reply

    expected_reply = %{
      "string" => [
        ["aaa", elem(DateTime.from_iso8601("2017-09-30 07:10:00.000Z"), 1)],
        ["bbb", elem(DateTime.from_iso8601("2017-09-30 07:12:00.000Z"), 1)],
        ["ccc", elem(DateTime.from_iso8601("2017-09-30 07:13:00.000Z"), 1)]
      ],
      "value" => [
        [1.1, elem(DateTime.from_iso8601("2017-09-30 07:10:00.000Z"), 1)],
        [2.2, elem(DateTime.from_iso8601("2017-09-30 07:12:00.000Z"), 1)],
        [3.3, elem(DateTime.from_iso8601("2017-09-30 07:13:00.000Z"), 1)]
      ]
    }

    opts = %{"format" => "disjoint_tables"}

    assert unpack_interface_values(
             Device.get_interface_values!(test, device_id, "com.example.TestObject", opts)
           ) == expected_reply
  end

  test "get_interface_values! returns path_not_found if there are no data" do
    test = "autotestrealm"
    device_id = "f0VMRgIBAQAAAAAAAAAAAA"

    {:ok, client} = Database.connect(test)
    DatabaseQuery.call!(client, "TRUNCATE com_example_testobject_v1")
    DatabaseQuery.call!(client, "TRUNCATE individual_properties")

    expected_reply = {:ok, %InterfaceValues{data: []}}

    assert Device.get_interface_values!(test, device_id, "com.example.TestObject", %{}) ==
             expected_reply
  end

  test "update_interface_values!/6" do
    test_realm = "autotestrealm"
    missing_id = "f0VMRgIBAQAAAAAAAAAAAQ"
    test_interface = "com.example.PixelsConfiguration"
    value = "#ff00ff"
    path = "/1/2/color"
    par = %{}

    assert Device.update_interface_values!(
             test_realm,
             missing_id,
             test_interface,
             path,
             value,
             par
           ) == {:error, :device_not_found}

    device_id = "f0VMRgIBAQAAAAAAAAAAAA"
    short_path = "/something"

    assert Device.update_interface_values!(
             test_realm,
             device_id,
             test_interface,
             short_path,
             value,
             par
           ) == {:error, :read_only_resource}

    ro_interface = "com.test.SimpleStreamTest"
    ro_path = "/0/value"

    assert Device.update_interface_values!(
             test_realm,
             device_id,
             ro_interface,
             ro_path,
             value,
             par
           ) == {:error, :cannot_write_to_device_owned}

    missing_interface = "com.test.Missing"

    assert Device.update_interface_values!(
             test_realm,
             device_id,
             missing_interface,
             ro_path,
             value,
             par
           ) == {:error, :interface_not_in_introspection}
  end

  test "device_alias_to_device_id/2 returns device IDs (uuid)" do
    assert Device.device_alias_to_device_id("autotestrealm", "device_a") ==
             {:ok, <<127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}

    assert Device.device_alias_to_device_id("autotestrealm", "device_b") ==
             {:ok, <<225, 68, 27, 34, 137, 46, 70, 231, 221, 181, 181, 89, 183, 208, 44, 46>>}

    assert Device.device_alias_to_device_id("autotestrealm", "1234") ==
             {:ok, <<225, 68, 27, 34, 137, 46, 70, 231, 221, 181, 181, 89, 183, 208, 44, 46>>}

    assert Device.device_alias_to_device_id("autotestrealm", "device_c") ==
             {:ok, <<105, 102, 160, 249, 89, 85, 40, 47, 190, 213, 47, 175, 127, 54, 125, 185>>}

    assert Device.device_alias_to_device_id("autotestrealm", "device_d") ==
             {:ok, <<12, 172, 90, 121, 159, 75, 205, 70, 75, 207, 181, 143, 77, 48, 4, 0>>}

    assert Device.device_alias_to_device_id("autotestrealm", "device_e") ==
             {:error, :device_not_found}
  end

  test "update device aliases using merge_device_status!/3" do
    set_again_display_name = %{
      "aliases" => %{
        "display_name" => "device_a"
      }
    }

    assert Device.merge_device_status!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             set_again_display_name
           ) == {:error, :alias_already_in_use}

    assert Device.device_alias_to_device_id("autotestrealm", "device_a") ==
             {:ok, <<127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}

    assert Device.get_device_status!("autotestrealm", @expected_device_status.id) ==
             {:ok, @expected_device_status}

    change_display_name = %{
      "aliases" => %{
        "display_name" => "device_z"
      }
    }

    assert Device.merge_device_status!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             change_display_name
           ) == :ok

    assert Device.device_alias_to_device_id("autotestrealm", "device_z") ==
             {:ok, <<127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}

    assert Device.device_alias_to_device_id("autotestrealm", "device_a") ==
             {:error, :device_not_found}

    change_and_add_aliases = %{
      "aliases" => %{
        "display_name" => "device_x",
        "serial" => "7890"
      }
    }

    assert Device.merge_device_status!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             change_and_add_aliases
           ) == :ok

    assert Device.device_alias_to_device_id("autotestrealm", "device_x") ==
             {:ok, <<127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}

    assert Device.device_alias_to_device_id("autotestrealm", "7890") ==
             {:ok, <<127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}

    assert Device.device_alias_to_device_id("autotestrealm", "device_z") ==
             {:error, :device_not_found}

    assert Device.device_alias_to_device_id("autotestrealm", "device_a") ==
             {:error, :device_not_found}

    unset_and_change_aliases = %{
      "aliases" => %{
        "display_name" => "device_a",
        "serial" => nil
      }
    }

    assert Device.merge_device_status!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             unset_and_change_aliases
           ) == :ok

    unset_not_existing = %{
      "aliases" => %{
        "serial" => nil
      }
    }

    assert Device.merge_device_status!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             unset_not_existing
           ) == {:error, :alias_tag_not_found}

    assert Device.device_alias_to_device_id("autotestrealm", "device_a") ==
             {:ok, <<127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}

    assert Device.device_alias_to_device_id("autotestrealm", "7890") ==
             {:error, :device_not_found}

    assert Device.device_alias_to_device_id("autotestrealm", "device_z") ==
             {:error, :device_not_found}

    assert Device.device_alias_to_device_id("autotestrealm", "device_x") ==
             {:error, :device_not_found}

    try_to_set_alias_to_not_existing = %{
      "aliases" => %{
        "display_name" => "alias_to_not_existing",
        "serial" => nil
      }
    }

    assert Device.merge_device_status!(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAQ",
             try_to_set_alias_to_not_existing
           ) == {:error, :device_not_found}

    assert Device.get_device_status!("autotestrealm", @expected_device_status.id) ==
             {:ok, @expected_device_status}
  end

  test "list_devices/1 returns all devices" do
    expected_devices = [
      "4UQbIokuRufdtbVZt9AsLg",
      "DKxaeZ9LzUZLz7WPTTAEAA",
      "aWag-VlVKC--1S-vfzZ9uQ",
      "f0VMRgIBAQAAAAAAAAAAAA",
      "olFkumNuZ_J0f_d6-8XCDg"
    ]

    assert Enum.sort(retrieve_next_devices_list(false)) == expected_devices

    devices_with_details = retrieve_next_devices_list(true)

    for device <- devices_with_details do
      case device.id do
        "4UQbIokuRufdtbVZt9AsLg" ->
          assert device.total_received_bytes == 22

        "DKxaeZ9LzUZLz7WPTTAEAA" ->
          assert device.total_received_bytes == 300

        "aWag-VlVKC--1S-vfzZ9uQ" ->
          assert device.total_received_bytes == 0

        "f0VMRgIBAQAAAAAAAAAAAA" ->
          assert device.total_received_bytes == 4_500_000

        "olFkumNuZ_J0f_d6-8XCDg" ->
          assert device.total_received_bytes == 10
      end
    end

    assert length(devices_with_details) == 5
  end

  defp retrieve_next_devices_list(
         {:ok, %DevicesList{devices: devices, last_token: nil}},
         _details
       ) do
    devices
  end

  defp retrieve_next_devices_list(
         {:ok, %DevicesList{devices: devices, last_token: last_token}},
         details
       ) do
    retrieve_next_devices_list(
      Device.list_devices!("autotestrealm", %{
        "limit" => 2,
        "from_token" => last_token,
        "details" => details
      }),
      details
    ) ++ devices
  end

  defp retrieve_next_devices_list(details) do
    retrieve_next_devices_list(
      Device.list_devices!("autotestrealm", %{"limit" => 2, "details" => details}),
      details
    )
  end

  test "get_device_status!/2 returns the device_status with given id" do
    assert Device.get_device_status!("autotestrealm", @expected_device_status.id) ==
             {:ok, @expected_device_status}
  end

  defp unpack_interface_values({:ok, %InterfaceValues{data: values}}) do
    values
  end
end