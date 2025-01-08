#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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
  alias Astarte.AppEngine.API.Device.InterfaceInfo
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.DataAccess.Database
  alias CQEx.Query, as: DatabaseQuery

  alias Astarte.RPC.Protocol.VMQ.Plugin.{
    Call,
    Publish,
    PublishReply,
    Reply
  }

  import Mox

  @expected_introspection %{
    "com.example.PixelsConfiguration" => %InterfaceInfo{
      major: 1,
      minor: 0,
      exchanged_msgs: 4230,
      exchanged_bytes: 2_010_000
    },
    "com.example.ServerOwnedTestObject" => %InterfaceInfo{
      major: 1,
      minor: 0,
      exchanged_msgs: 100,
      exchanged_bytes: 30_000
    },
    "com.example.TestObject" => %InterfaceInfo{
      major: 1,
      minor: 5,
      exchanged_msgs: 9300,
      exchanged_bytes: 2_000_000
    },
    "com.test.LCDMonitor" => %InterfaceInfo{
      major: 1,
      minor: 3,
      exchanged_msgs: 10,
      exchanged_bytes: 3000
    },
    "com.test.SimpleStreamTest" => %InterfaceInfo{
      major: 1,
      minor: 0,
      exchanged_msgs: 0,
      exchanged_bytes: 0
    }
  }

  @expected_previous_interfaces [
    %InterfaceInfo{
      name: "com.test.LCDMonitor",
      major: 0,
      minor: 1,
      exchanged_msgs: 42,
      exchanged_bytes: 9000
    }
  ]

  @expected_device_status %DeviceStatus{
    connected: false,
    id: "f0VMRgIBAQAAAAAAAAAAAA",
    aliases: %{"display_name" => "device_a"},
    attributes: %{"attribute_key" => "device_a_attribute"},
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
    credentials_inhibited: false,
    total_received_bytes: 4_500_000,
    total_received_msgs: 45000,
    previous_interfaces: @expected_previous_interfaces,
    groups: [],
    deletion_in_progress: false
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
             "com.example.ServerOwnedTestObject",
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

    assert unpack_interface_values(
             Device.get_interface_values!(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               "com.test.LCDMonitor",
               "weekSchedule/9/start",
               %{}
             )
           ) == %{}

    assert unpack_interface_values(
             Device.get_interface_values!(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               "com.test.LCDMonitor",
               "weekSchedule/9",
               %{}
             )
           ) == %{}
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

    {:ok, client} = Database.connect(realm: test)
    DatabaseQuery.call!(client, "TRUNCATE com_example_testobject_v1")
    DatabaseQuery.call!(client, "TRUNCATE individual_properties")

    expected_reply = {:ok, %InterfaceValues{data: %{}}}

    assert Device.get_interface_values!(test, device_id, "com.example.TestObject", %{}) ==
             expected_reply
  end

  describe "update_interface_values with individual aggregation" do
    setup do
      DatabaseTestHelper.create_datastream_receiving_device()

      on_exit(fn ->
        DatabaseTestHelper.remove_datastream_receiving_device()
      end)
    end

    test "fails with invalid parameters" do
      test_realm = "autotestrealm"
      missing_id = "f0VMRgIBAQAAAAAAAAAAAQ"
      test_interface = "com.example.PixelsConfiguration"
      value = "#ff00ff"
      path = "/1/2/color"
      par = %{}

      assert Device.update_interface_values(
               test_realm,
               missing_id,
               test_interface,
               path,
               value,
               par
             ) == {:error, :device_not_found}

      device_id = "f0VMRgIBAQAAAAAAAAAAAA"
      short_path = "/something"

      assert Device.update_interface_values(
               test_realm,
               device_id,
               test_interface,
               short_path,
               value,
               par
             ) == {:error, :read_only_resource}

      ro_interface = "com.test.SimpleStreamTest"
      ro_path = "/0/value"

      assert Device.update_interface_values(
               test_realm,
               device_id,
               ro_interface,
               ro_path,
               value,
               par
             ) == {:error, :cannot_write_to_device_owned}

      missing_interface = "com.test.Missing"

      assert Device.update_interface_values(
               test_realm,
               device_id,
               missing_interface,
               ro_path,
               value,
               par
             ) == {:error, :interface_not_in_introspection}
    end

    test "is successful and data on the interface can be retrieved" do
      test_realm = "autotestrealm"
      device_id = "fmloLzG5T5u0aOUfIkL8KA"
      test_interface = "org.ServerOwnedIndividual"
      value = 10
      path = "/1/samplingPeriod"
      par = %{}

      request_ts_1 = DateTime.utc_now()

      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, _destination ->
        assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

        encoded_payload = Cyanide.encode!(%{v: value})
        path_tokens = String.split(path, "/")

        assert %Publish{
                 topic_tokens: [^test_realm, ^device_id, ^test_interface | ^path_tokens],
                 payload: ^encoded_payload,
                 qos: 2
               } = publish_call

        {:ok,
         %Reply{
           reply: tagged_publish_reply(1)
         }
         |> Reply.encode()}
      end)

      assert Device.update_interface_values(
               test_realm,
               device_id,
               test_interface,
               path,
               value,
               par
             ) ==
               {:ok,
                %Astarte.AppEngine.API.Device.InterfaceValues{
                  data: 10,
                  metadata: nil
                }}

      path = "/2/samplingPeriod"
      value = 11

      request_ts_2 = DateTime.utc_now()

      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, _destination ->
        assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

        encoded_payload = Cyanide.encode!(%{v: value})
        path_tokens = String.split(path, "/")

        assert %Publish{
                 topic_tokens: [^test_realm, ^device_id, ^test_interface | ^path_tokens],
                 payload: ^encoded_payload,
                 qos: 2
               } = publish_call

        {:ok,
         %Reply{
           reply: tagged_publish_reply(1)
         }
         |> Reply.encode()}
      end)

      assert Device.update_interface_values(
               test_realm,
               device_id,
               test_interface,
               path,
               value,
               par
             ) ==
               {:ok,
                %Astarte.AppEngine.API.Device.InterfaceValues{
                  data: 11,
                  metadata: nil
                }}

      result = Device.get_interface_values!(test_realm, device_id, test_interface, %{})

      assert {:ok,
              %Astarte.AppEngine.API.Device.InterfaceValues{
                data: %{
                  "1" => %{
                    "samplingPeriod" => %{
                      "reception_timestamp" => reception_ts_1,
                      "timestamp" => ts_1,
                      "value" => 10
                    }
                  },
                  "2" => %{
                    "samplingPeriod" => %{
                      "reception_timestamp" => reception_ts_2,
                      "timestamp" => ts_2,
                      "value" => 11
                    }
                  }
                },
                metadata: nil
              }} = result

      assert_in_delta(DateTime.to_unix(request_ts_1), DateTime.to_unix(ts_1), 1000)
      assert_in_delta(DateTime.to_unix(request_ts_2), DateTime.to_unix(ts_2), 1000)
    end

    test "is successful when PublishReply contains a remote_match or multiple matches" do
      test_realm = "autotestrealm"
      device_id = "fmloLzG5T5u0aOUfIkL8KA"
      test_interface = "org.ServerOwnedIndividual"
      value = 10
      path = "/1/samplingPeriod"
      par = %{}

      request_ts_1 = DateTime.utc_now()

      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, _destination ->
        assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

        encoded_payload = Cyanide.encode!(%{v: value})
        path_tokens = String.split(path, "/")

        assert %Publish{
                 topic_tokens: [^test_realm, ^device_id, ^test_interface | ^path_tokens],
                 payload: ^encoded_payload,
                 qos: 2
               } = publish_call

        {:ok,
         %Reply{
           # Remote match
           reply: tagged_publish_reply(0, 1)
         }
         |> Reply.encode()}
      end)

      assert Device.update_interface_values(
               test_realm,
               device_id,
               test_interface,
               path,
               value,
               par
             ) ==
               {:ok,
                %Astarte.AppEngine.API.Device.InterfaceValues{
                  data: 10,
                  metadata: nil
                }}

      path = "/2/samplingPeriod"
      value = 11

      request_ts_2 = DateTime.utc_now()

      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, _destination ->
        assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

        encoded_payload = Cyanide.encode!(%{v: value})
        path_tokens = String.split(path, "/")

        assert %Publish{
                 topic_tokens: [^test_realm, ^device_id, ^test_interface | ^path_tokens],
                 payload: ^encoded_payload,
                 qos: 2
               } = publish_call

        {:ok,
         %Reply{
           # Multiple matches
           reply: tagged_publish_reply(2, 3)
         }
         |> Reply.encode()}
      end)

      assert Device.update_interface_values(
               test_realm,
               device_id,
               test_interface,
               path,
               value,
               par
             ) ==
               {:ok,
                %Astarte.AppEngine.API.Device.InterfaceValues{
                  data: 11,
                  metadata: nil
                }}

      result = Device.get_interface_values!(test_realm, device_id, test_interface, %{})

      assert {:ok,
              %Astarte.AppEngine.API.Device.InterfaceValues{
                data: %{
                  "1" => %{
                    "samplingPeriod" => %{
                      "reception_timestamp" => reception_ts_1,
                      "timestamp" => ts_1,
                      "value" => 10
                    }
                  },
                  "2" => %{
                    "samplingPeriod" => %{
                      "reception_timestamp" => reception_ts_2,
                      "timestamp" => ts_2,
                      "value" => 11
                    }
                  }
                },
                metadata: nil
              }} = result

      assert_in_delta(DateTime.to_unix(request_ts_1), DateTime.to_unix(ts_1), 1000)
      assert_in_delta(DateTime.to_unix(request_ts_2), DateTime.to_unix(ts_2), 1000)
    end

    test "fails if PublishReply does not contain matches" do
      test_realm = "autotestrealm"
      device_id = "fmloLzG5T5u0aOUfIkL8KA"
      test_interface = "org.ServerOwnedIndividual"
      value = 10
      path = "/1/samplingPeriod"
      par = %{}

      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, _destination ->
        assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

        encoded_payload = Cyanide.encode!(%{v: value})
        path_tokens = String.split(path, "/")

        assert %Publish{
                 topic_tokens: [^test_realm, ^device_id, ^test_interface | ^path_tokens],
                 payload: ^encoded_payload,
                 qos: 2
               } = publish_call

        {:ok,
         %Reply{
           reply: tagged_publish_reply(0)
         }
         |> Reply.encode()}
      end)

      assert Device.update_interface_values(
               test_realm,
               device_id,
               test_interface,
               path,
               value,
               par
             ) == {:error, :cannot_push_to_device}
    end
  end

  describe "update_interface_values with object aggregation" do
    setup do
      DatabaseTestHelper.create_object_receiving_device()

      on_exit(fn ->
        DatabaseTestHelper.remove_object_receiving_device()
      end)
    end

    test "fails with unexpected type" do
      test_realm = "autotestrealm"
      device_id = "fmloLzG5T5u0aOUfIkL8KA"
      interface = "org.astarte-platform.genericsensors.ServerOwnedAggregateObj"
      path = "/my_path"
      par = nil

      assert Device.update_interface_values(
               test_realm,
               device_id,
               interface,
               path,
               %{"enable" => "true", "samplingPeriod" => 10},
               par
             ) == {:error, :unexpected_value_type, expected: :boolean}
    end

    test "fails with unexpected key" do
      test_realm = "autotestrealm"
      device_id = "fmloLzG5T5u0aOUfIkL8KA"
      interface = "org.astarte-platform.genericsensors.ServerOwnedAggregateObj"
      path = "/my_path"
      value = %{"enable" => true, "samplingPeriod" => 10, "invalidKey" => true}
      par = nil

      assert Device.update_interface_values(
               test_realm,
               device_id,
               interface,
               path,
               value,
               par
             ) == {:error, :unexpected_object_key}
    end

    test "fails with invalid path" do
      test_realm = "autotestrealm"
      device_id = "fmloLzG5T5u0aOUfIkL8KA"
      interface = "org.astarte-platform.genericsensors.ServerOwnedAggregateObj"
      value = %{"enable" => true, "samplingPeriod" => 10}
      par = nil

      assert Device.update_interface_values(
               test_realm,
               device_id,
               interface,
               "/",
               value,
               par
             ) == {:error, :mapping_not_found}
    end

    test "fails when path cannot be resolved" do
      test_realm = "autotestrealm"
      device_id = "fmloLzG5T5u0aOUfIkL8KA"
      interface = "org.astarte-platform.genericsensors.ServerOwnedAggregateObj"
      value = %{"enable" => true, "samplingPeriod" => 10}
      par = nil

      assert Device.update_interface_values(
               test_realm,
               device_id,
               interface,
               "/a/b",
               value,
               par
             ) == {:error, :mapping_not_found}
    end

    test "is successful and data on the interface can be retrieved" do
      test_realm = "autotestrealm"
      device_id = "fmloLzG5T5u0aOUfIkL8KA"
      interface = "org.astarte-platform.genericsensors.ServerOwnedAggregateObj"
      path = "/my_path"
      value = %{"enable" => true, "samplingPeriod" => 10}
      par = nil

      request_ts_1 = DateTime.utc_now()

      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, _destination ->
        assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

        encoded_payload = Cyanide.encode!(%{v: value})
        path_tokens = String.split(path, "/")

        assert %Publish{
                 topic_tokens: [^test_realm, ^device_id, ^interface | ^path_tokens],
                 payload: ^encoded_payload,
                 qos: 2
               } = publish_call

        {:ok,
         %Reply{
           reply: tagged_publish_reply(1)
         }
         |> Reply.encode()}
      end)

      assert Device.update_interface_values(
               test_realm,
               device_id,
               interface,
               path,
               value,
               par
             ) ==
               {:ok,
                %Astarte.AppEngine.API.Device.InterfaceValues{
                  data: %{"enable" => true, "samplingPeriod" => 10},
                  metadata: nil
                }}

      path = "/my_new_path"
      value = %{"enable" => false, "samplingPeriod" => 100}

      request_ts_2 = DateTime.utc_now()

      MockRPCClient
      |> expect(:rpc_call, 2, fn serialized_call, _destination ->
        assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

        encoded_payload = Cyanide.encode!(%{v: value})
        path_tokens = String.split(path, "/")

        assert %Publish{
                 topic_tokens: [^test_realm, ^device_id, ^interface | ^path_tokens],
                 payload: ^encoded_payload,
                 qos: 2
               } = publish_call

        {:ok,
         %Reply{
           reply: tagged_publish_reply(1)
         }
         |> Reply.encode()}
      end)

      assert Device.update_interface_values(
               test_realm,
               device_id,
               interface,
               path,
               value,
               par
             ) ==
               {:ok,
                %Astarte.AppEngine.API.Device.InterfaceValues{
                  data: %{"enable" => false, "samplingPeriod" => 100},
                  metadata: nil
                }}

      result = Device.get_interface_values!(test_realm, device_id, interface, %{})

      assert {:ok,
              %Astarte.AppEngine.API.Device.InterfaceValues{
                data: %{
                  "my_new_path" => %{
                    "enable" => false,
                    "samplingPeriod" => 100,
                    "timestamp" => time1
                  },
                  "my_path" => %{
                    "enable" => true,
                    "samplingPeriod" => 10,
                    "timestamp" => time2
                  }
                },
                metadata: nil
              }} = result

      assert_in_delta(DateTime.to_unix(request_ts_1), DateTime.to_unix(time1), 1000)
      assert_in_delta(DateTime.to_unix(request_ts_2), DateTime.to_unix(time2), 1000)
    end

    test "is successful with binaryblob arrays in object-aggregated payloads and data on the interface can be retrieved" do
      test_realm = "autotestrealm"
      device_id = "fmloLzG5T5u0aOUfIkL8KA"
      interface = "org.astarte-platform.genericsensors.ServerOwnedAggregateObj"
      path = "/my_path"
      values = [<<1, 2, 3, 230>>, <<4, 5, 6, 230>>]
      server_owned_value = %{"binaryblobarray" => Enum.map(values, &Base.encode64/1)}
      par = nil

      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, _destination ->
        assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

        encoded_payload =
          %{v: %{"binaryblobarray" => Enum.map(values, &{0, &1})}} |> Cyanide.encode!()

        path_tokens = String.split(path, "/")

        assert %Publish{
                 topic_tokens: [^test_realm, ^device_id, ^interface | ^path_tokens],
                 payload: ^encoded_payload,
                 qos: 2
               } = publish_call

        {:ok,
         %Reply{
           reply: tagged_publish_reply(1)
         }
         |> Reply.encode()}
      end)

      assert Device.update_interface_values(
               test_realm,
               device_id,
               interface,
               path,
               server_owned_value,
               par
             ) ==
               {:ok,
                %Astarte.AppEngine.API.Device.InterfaceValues{
                  data: server_owned_value,
                  metadata: nil
                }}
    end

    test "is successful when PublishReply contains a remote_match or multiple matches" do
      test_realm = "autotestrealm"
      device_id = "fmloLzG5T5u0aOUfIkL8KA"
      interface = "org.astarte-platform.genericsensors.ServerOwnedAggregateObj"
      path = "/my_path"
      value = %{"enable" => true, "samplingPeriod" => 10}
      par = nil

      request_ts_1 = DateTime.utc_now()

      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, _destination ->
        assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

        encoded_payload = Cyanide.encode!(%{v: value})
        path_tokens = String.split(path, "/")

        assert %Publish{
                 topic_tokens: [^test_realm, ^device_id, ^interface | ^path_tokens],
                 payload: ^encoded_payload,
                 qos: 2
               } = publish_call

        {:ok,
         %Reply{
           # Remote match
           reply: tagged_publish_reply(0, 1)
         }
         |> Reply.encode()}
      end)

      assert Device.update_interface_values(
               test_realm,
               device_id,
               interface,
               path,
               value,
               par
             ) ==
               {:ok,
                %Astarte.AppEngine.API.Device.InterfaceValues{
                  data: %{"enable" => true, "samplingPeriod" => 10},
                  metadata: nil
                }}

      path = "/my_new_path"
      value = %{"enable" => false, "samplingPeriod" => 100}

      request_ts_2 = DateTime.utc_now()

      MockRPCClient
      |> expect(:rpc_call, 2, fn serialized_call, _destination ->
        assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

        encoded_payload = Cyanide.encode!(%{v: value})
        path_tokens = String.split(path, "/")

        assert %Publish{
                 topic_tokens: [^test_realm, ^device_id, ^interface | ^path_tokens],
                 payload: ^encoded_payload,
                 qos: 2
               } = publish_call

        {:ok,
         %Reply{
           # Multiple matches
           reply: tagged_publish_reply(2, 3)
         }
         |> Reply.encode()}
      end)

      assert Device.update_interface_values(
               test_realm,
               device_id,
               interface,
               path,
               value,
               par
             ) ==
               {:ok,
                %Astarte.AppEngine.API.Device.InterfaceValues{
                  data: %{"enable" => false, "samplingPeriod" => 100},
                  metadata: nil
                }}

      result = Device.get_interface_values!(test_realm, device_id, interface, %{})

      assert {:ok,
              %Astarte.AppEngine.API.Device.InterfaceValues{
                data: %{
                  "my_new_path" => %{
                    "enable" => false,
                    "samplingPeriod" => 100,
                    "timestamp" => time1
                  },
                  "my_path" => %{
                    "enable" => true,
                    "samplingPeriod" => 10,
                    "timestamp" => time2
                  }
                },
                metadata: nil
              }} = result

      assert_in_delta(DateTime.to_unix(request_ts_1), DateTime.to_unix(time1), 1000)
      assert_in_delta(DateTime.to_unix(request_ts_2), DateTime.to_unix(time2), 1000)
    end

    test "fails if PublishReply does not contain matches" do
      test_realm = "autotestrealm"
      device_id = "fmloLzG5T5u0aOUfIkL8KA"
      interface = "org.astarte-platform.genericsensors.ServerOwnedAggregateObj"
      path = "/my_path"
      value = %{"enable" => true, "samplingPeriod" => 10}
      par = nil

      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, _destination ->
        assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

        encoded_payload = Cyanide.encode!(%{v: value})
        path_tokens = String.split(path, "/")

        assert %Publish{
                 topic_tokens: [^test_realm, ^device_id, ^interface | ^path_tokens],
                 payload: ^encoded_payload,
                 qos: 2
               } = publish_call

        {:ok,
         %Reply{
           reply: tagged_publish_reply(0)
         }
         |> Reply.encode()}
      end)

      assert Device.update_interface_values(
               test_realm,
               device_id,
               interface,
               path,
               value,
               par
             ) == {:error, :cannot_push_to_device}
    end
  end

  describe "ttl is handled properly for server owned individual interface" do
    setup do
      DatabaseTestHelper.create_datastream_receiving_device()
      DatabaseTestHelper.set_realm_ttl(5)

      on_exit(fn ->
        DatabaseTestHelper.unset_realm_ttl()
        DatabaseTestHelper.remove_datastream_receiving_device()
      end)
    end

    test "update_interface_values" do
      test_realm = "autotestrealm"
      device_id = "fmloLzG5T5u0aOUfIkL8KA"
      test_interface = "org.ServerOwnedIndividual"
      value = 10
      path = "/1/samplingPeriod"
      par = %{}

      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, _destination ->
        assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

        encoded_payload = Cyanide.encode!(%{v: value})
        path_tokens = String.split(path, "/")

        assert %Publish{
                 topic_tokens: [^test_realm, ^device_id, ^test_interface | ^path_tokens],
                 payload: ^encoded_payload,
                 qos: 2
               } = publish_call

        {:ok,
         %Reply{
           reply: tagged_publish_reply(1)
         }
         |> Reply.encode()}
      end)

      assert Device.update_interface_values(
               test_realm,
               device_id,
               test_interface,
               path,
               value,
               par
             ) ==
               {:ok,
                %Astarte.AppEngine.API.Device.InterfaceValues{
                  data: 10,
                  metadata: nil
                }}

      :timer.sleep(6000)

      assert Device.get_interface_values!(test_realm, device_id, test_interface, %{}) ==
               {:ok,
                %Astarte.AppEngine.API.Device.InterfaceValues{
                  data: %{},
                  metadata: nil
                }}
    end
  end

  describe "ttl is handled properly for server owned object aggregated interface" do
    setup do
      DatabaseTestHelper.create_object_receiving_device()
      DatabaseTestHelper.set_realm_ttl(5)

      on_exit(fn ->
        DatabaseTestHelper.unset_realm_ttl()
        DatabaseTestHelper.remove_object_receiving_device()
      end)
    end

    test "update_interface_values" do
      test_realm = "autotestrealm"
      device_id = "fmloLzG5T5u0aOUfIkL8KA"
      test_interface = "org.astarte-platform.genericsensors.ServerOwnedAggregateObj"
      path = "/my_path"
      value = %{"enable" => true, "samplingPeriod" => 10}
      par = nil

      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, _destination ->
        assert %Call{call: {:publish, %Publish{} = publish_call}} = Call.decode(serialized_call)

        encoded_payload = Cyanide.encode!(%{v: value})
        path_tokens = String.split(path, "/")

        assert %Publish{
                 topic_tokens: [^test_realm, ^device_id, ^test_interface | ^path_tokens],
                 payload: ^encoded_payload,
                 qos: 2
               } = publish_call

        {:ok,
         %Reply{
           reply: tagged_publish_reply(1)
         }
         |> Reply.encode()}
      end)

      assert Device.update_interface_values(
               test_realm,
               device_id,
               test_interface,
               path,
               value,
               par
             ) ==
               {:ok,
                %Astarte.AppEngine.API.Device.InterfaceValues{
                  data: %{"enable" => true, "samplingPeriod" => 10},
                  metadata: nil
                }}

      :timer.sleep(6000)

      assert Device.get_interface_values!(test_realm, device_id, test_interface, %{}) ==
               {:ok,
                %Astarte.AppEngine.API.Device.InterfaceValues{
                  data: %{},
                  metadata: nil
                }}
    end
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
             {:ok, <<122, 19, 105, 108, 245, 109, 67, 96, 156, 116, 151, 73, 43, 116, 20, 148>>}

    assert Device.device_alias_to_device_id("autotestrealm", "device_f") ==
             {:error, :device_not_found}
  end

  test "update device aliases using merge_device_status/3" do
    # Succeeds when setting an alias that is already assigned to this device
    set_again_display_name = %{
      "aliases" => %{
        "display_name" => "device_a"
      }
    }

    assert {:ok, _device_status} =
             Device.merge_device_status(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               set_again_display_name
             )

    assert Device.device_alias_to_device_id("autotestrealm", "device_a") ==
             {:ok, <<127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}

    assert Device.get_device_status!("autotestrealm", @expected_device_status.id) ==
             {:ok, @expected_device_status}

    # Fails when setting an alias that is already assigned to another device
    already_existing_display_name = %{
      "aliases" => %{
        "display_name" => "device_b"
      }
    }

    assert Device.merge_device_status(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             already_existing_display_name
           ) == {:error, :alias_already_in_use}

    assert Device.device_alias_to_device_id("autotestrealm", "device_b") ==
             {:ok, <<225, 68, 27, 34, 137, 46, 70, 231, 221, 181, 181, 89, 183, 208, 44, 46>>}

    change_display_name = %{
      "aliases" => %{
        "display_name" => "device_z"
      }
    }

    assert {:ok, %DeviceStatus{aliases: %{"display_name" => "device_z"}}} =
             Device.merge_device_status(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               change_display_name
             )

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

    assert {:ok, %DeviceStatus{aliases: %{"display_name" => "device_x", "serial" => "7890"}}} =
             Device.merge_device_status(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               change_and_add_aliases
             )

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

    assert {:ok, %DeviceStatus{aliases: aliases}} =
             Device.merge_device_status(
               "autotestrealm",
               "f0VMRgIBAQAAAAAAAAAAAA",
               unset_and_change_aliases
             )

    assert Map.get(aliases, "display_name") == "device_a"
    assert Enum.member?(aliases, "serial") == false

    unset_not_existing = %{
      "aliases" => %{
        "serial" => nil
      }
    }

    assert Device.merge_device_status(
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

    assert Device.merge_device_status(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAQ",
             try_to_set_alias_to_not_existing
           ) == {:error, :device_not_found}

    assert Device.get_device_status!("autotestrealm", @expected_device_status.id) ==
             {:ok, @expected_device_status}
  end

  test "update device attributes using merge_device_status/3" do
    params = %{"attributes" => %{"attribute_key" => "new_attribute"}}

    assert Device.merge_device_status(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             params
           ) ==
             {:ok,
              Map.put(@expected_device_status, :attributes, %{
                "attribute_key" => "new_attribute"
              })}
  end

  test "empty value is ok when updating device attributes using merge_device_status/3" do
    params = %{"attributes" => %{"attribute_key" => ""}}

    assert Device.merge_device_status(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             params
           ) == {:ok, Map.put(@expected_device_status, :attributes, %{"attribute_key" => ""})}
  end

  test "empty key returns an error when updating device attributes using merge_device_status/3" do
    params = %{"attributes" => %{"" => "attribute_val"}}

    assert Device.merge_device_status(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             params
           ) == {:error, :invalid_attributes}
  end

  test "empty key returns an error when updating device aliases using merge_device_status/3" do
    params = %{"aliases" => %{"" => "alias_val"}}

    assert Device.merge_device_status(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             params
           ) == {:error, :invalid_alias}
  end

  test "empty value leaves the status unchanged when updating device aliases using merge_device_status/3" do
    params = %{"aliases" => %{"alias_key" => ""}}

    assert Device.merge_device_status(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             params
           ) == {:error, :invalid_alias}
  end

  test "delete attributes with existing key using merge_device_status" do
    modified_attributes = %{"attributes" => %{"attribute_key" => nil}}

    assert Device.merge_device_status(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             modified_attributes
           ) == {:ok, Map.put(@expected_device_status, :attributes, %{})}
  end

  test "delete attributes with non existing key using merge_device_status" do
    modified_attributes = %{"attributes" => %{"non_existing_key" => nil}}

    assert Device.merge_device_status(
             "autotestrealm",
             "f0VMRgIBAQAAAAAAAAAAAA",
             modified_attributes
           ) == {:error, :attribute_key_not_found}
  end

  describe "updating credentials_inhibited with merge_device_status/3" do
    test "succeeds when changing value" do
      params = %{"credentials_inhibited" => true}

      assert {:ok, %DeviceStatus{credentials_inhibited: true}} =
               Device.merge_device_status("autotestrealm", "f0VMRgIBAQAAAAAAAAAAAA", params)
    end

    test "succeeds when leaving the same value" do
      params = %{"credentials_inhibited" => false}

      assert {:ok, %DeviceStatus{credentials_inhibited: false}} =
               Device.merge_device_status("autotestrealm", "f0VMRgIBAQAAAAAAAAAAAA", params)
    end

    test "fails with invalid value" do
      params = %{"credentials_inhibited" => "invalid"}

      assert {:error, %Ecto.Changeset{}} =
               Device.merge_device_status("autotestrealm", "f0VMRgIBAQAAAAAAAAAAAA", params)
    end
  end

  test "list_devices/1 returns all devices" do
    expected_devices = [
      "4UQbIokuRufdtbVZt9AsLg",
      "DKxaeZ9LzUZLz7WPTTAEAA",
      "aWag-VlVKC--1S-vfzZ9uQ",
      "ehNpbPVtQ2CcdJdJK3QUlA",
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

        "ehNpbPVtQ2CcdJdJK3QUlA" ->
          assert device.deletion_in_progress == true
      end
    end

    assert length(devices_with_details) == 6
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

  test "get_device_status!/2 returns the device_status with correct deletion_in_progress value" do
    deleted_device_id = "ehNpbPVtQ2CcdJdJK3QUlA"

    assert {:ok, deleted_device_status} =
             Device.get_device_status!("autotestrealm", deleted_device_id)

    assert %{
             id: ^deleted_device_id,
             deletion_in_progress: true
           } = deleted_device_status
  end

  defp unpack_interface_values({:ok, %InterfaceValues{data: values}}) do
    values
  end

  defp tagged_publish_reply(local_matches, remote_matches \\ 0) do
    reply = PublishReply.new(local_matches: local_matches, remote_matches: remote_matches)
    {:publish_reply, reply}
  end
end
