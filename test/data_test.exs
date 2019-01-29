#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.DataAccess.DataTest do
  use ExUnit.Case
  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.DataAccess.DatabaseTestHelper
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Data
  alias Astarte.DataAccess.Mappings
  alias Astarte.DataAccess.Interface

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

  test "check if path exists" do
    {:ok, db_client} = Database.connect("autotestrealm")

    {:ok, device_id} = CoreDevice.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

    {:ok, descriptor} = Interface.fetch_interface_descriptor(db_client, "com.test.LCDMonitor", 1)
    %InterfaceDescriptor{interface_id: interface_id} = descriptor

    {:ok, mappings} = Mappings.fetch_interface_mappings_map(db_client, interface_id)

    mapping =
      mappings
      |> Map.values()
      |> Enum.find(fn mapping -> mapping.endpoint == "/weekSchedule/%{day}/stop" end)

    assert Data.path_exists?(db_client, device_id, descriptor, mapping, "/weekSchedule/3/stop") ==
             {:ok, true}

    assert Data.path_exists?(db_client, device_id, descriptor, mapping, "/weekSchedule/9/stop") ==
             {:ok, false}
  end

  test "fetch property value on a certain interface" do
    {:ok, db_client} = Database.connect("autotestrealm")

    {:ok, device_id} = CoreDevice.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

    {:ok, descriptor} = Interface.fetch_interface_descriptor(db_client, "com.test.LCDMonitor", 1)
    %InterfaceDescriptor{interface_id: interface_id} = descriptor

    {:ok, mappings} = Mappings.fetch_interface_mappings_map(db_client, interface_id)

    mapping =
      mappings
      |> Map.values()
      |> Enum.find(fn mapping -> mapping.endpoint == "/weekSchedule/%{day}/stop" end)

    assert Data.fetch_property(db_client, device_id, descriptor, mapping, "/weekSchedule/3/stop") ==
             {:ok, 16}

    assert Data.fetch_property(db_client, device_id, descriptor, mapping, "/weekSchedule/9/stop") ==
             {:error, :property_not_set}
  end

  test "fetch last path update" do
    {:ok, db_client} = Database.connect("autotestrealm")

    {:ok, device_id} = CoreDevice.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

    {:ok, descriptor} =
      Interface.fetch_interface_descriptor(db_client, "com.test.SimpleStreamTest", 1)

    %InterfaceDescriptor{interface_id: interface_id} = descriptor

    {:ok, mappings} = Mappings.fetch_interface_mappings_map(db_client, interface_id)

    mapping =
      mappings
      |> Map.values()
      |> Enum.find(fn mapping -> mapping.endpoint == "/%{itemIndex}/value" end)

    {:ok, reception_timestamp, _} = DateTime.from_iso8601("2017-09-30 07:10:00.000000Z")
    {:ok, value_timestamp, _} = DateTime.from_iso8601("2017-09-30 07:11:00.000Z")

    assert Data.fetch_last_path_update(db_client, device_id, descriptor, mapping, "/0/value") ==
             {:ok,
              %{
                reception_timestamp: reception_timestamp,
                value_timestamp: value_timestamp
              }}
  end
end
