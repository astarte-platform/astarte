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

defmodule Astarte.DataAccess.Data.XandraTest do
  use ExUnit.Case
  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.DataAccess.DatabaseTestHelper
  alias Astarte.DataAccess.Data
  alias Astarte.DataAccess.Interface
  alias Astarte.DataAccess.Mappings

  @test_realm "autotestrealm"

  setup do
    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.seed_data(conn)
    end)
  end

  setup_all do
    Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
      DatabaseTestHelper.create_test_keyspace(conn)
    end)

    on_exit(fn ->
      Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
        DatabaseTestHelper.destroy_local_test_keyspace(conn)
      end)
    end)

    :ok
  end

  test "check if path exists" do
    {:ok, device_id} = CoreDevice.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

    {:ok, descriptor} =
      Interface.fetch_interface_descriptor(@test_realm, "com.test.LCDMonitor", 1)

    %InterfaceDescriptor{interface_id: interface_id} = descriptor

    {:ok, mappings} = Mappings.fetch_interface_mappings_map(@test_realm, interface_id)

    mapping =
      mappings
      |> Map.values()
      |> Enum.find(fn mapping -> mapping.endpoint == "/weekSchedule/%{day}/stop" end)

    assert Data.path_exists?(
             @test_realm,
             device_id,
             descriptor,
             mapping,
             "/weekSchedule/3/stop"
           ) ==
             {:ok, true}

    assert Data.path_exists?(
             @test_realm,
             device_id,
             descriptor,
             mapping,
             "/weekSchedule/9/stop"
           ) ==
             {:ok, false}
  end

  test "fetch property value on a certain interface" do
    {:ok, device_id} = CoreDevice.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

    {:ok, descriptor} =
      Interface.fetch_interface_descriptor(@test_realm, "com.test.LCDMonitor", 1)

    %InterfaceDescriptor{interface_id: interface_id} = descriptor

    {:ok, mappings} = Mappings.fetch_interface_mappings_map(@test_realm, interface_id)

    mapping =
      mappings
      |> Map.values()
      |> Enum.find(fn mapping -> mapping.endpoint == "/weekSchedule/%{day}/stop" end)

    assert Data.fetch_property(
             @test_realm,
             device_id,
             descriptor,
             mapping,
             "/weekSchedule/3/stop"
           ) ==
             {:ok, 16}

    assert Data.fetch_property(
             @test_realm,
             device_id,
             descriptor,
             mapping,
             "/weekSchedule/9/stop"
           ) ==
             {:error, :property_not_set}
  end

  test "fetch last path update" do
    {:ok, device_id} = CoreDevice.decode_device_id("f0VMRgIBAQAAAAAAAAAAAA")

    {:ok, descriptor} =
      Interface.fetch_interface_descriptor(
        @test_realm,
        "com.test.SimpleStreamTest",
        1
      )

    %InterfaceDescriptor{interface_id: interface_id} = descriptor

    {:ok, mappings} = Mappings.fetch_interface_mappings_map(@test_realm, interface_id)

    mapping =
      mappings
      |> Map.values()
      |> Enum.find(fn mapping -> mapping.endpoint == "/%{itemIndex}/value" end)

    {:ok, reception_timestamp, _} = DateTime.from_iso8601("2017-09-30 07:10:00.000000Z")
    {:ok, value_timestamp, _} = DateTime.from_iso8601("2017-09-30 07:11:00.000Z")

    assert Data.fetch_last_path_update(
             @test_realm,
             device_id,
             descriptor,
             mapping,
             "/0/value"
           ) ==
             {:ok,
              %{
                reception_timestamp: reception_timestamp,
                value_timestamp: value_timestamp
              }}
  end
end
