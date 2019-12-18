#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.AppEngine.API.StatsTest do
  use ExUnit.Case
  alias Astarte.AppEngine.API.DatabaseTestHelper
  alias Astarte.AppEngine.API.Stats
  alias Astarte.AppEngine.API.Stats.DevicesStats

  setup_all do
    {:ok, _client} = DatabaseTestHelper.create_test_keyspace()

    on_exit(fn ->
      DatabaseTestHelper.destroy_local_test_keyspace()
    end)

    :ok
  end

  setup do
    DatabaseTestHelper.seed_data()
  end

  describe "get_devices_stats" do
    test "returns an error for unexisting realm" do
      assert {:error, _reason} = Stats.get_devices_stats("unexisting")
    end

    test "returns the correct stats for the autotestrealm" do
      assert {:ok, %DevicesStats{} = stats} = Stats.get_devices_stats("autotestrealm")

      assert stats.total_devices == DatabaseTestHelper.devices_count()
      assert stats.connected_devices == 0
    end

    test "gets updated connected count after device connection" do
      assert {:ok, %DevicesStats{connected_devices: 0}} = Stats.get_devices_stats("autotestrealm")

      DatabaseTestHelper.fake_connect_device("f0VMRgIBAQAAAAAAAAAAAA", true)

      assert {:ok, %DevicesStats{connected_devices: 1}} = Stats.get_devices_stats("autotestrealm")

      DatabaseTestHelper.fake_connect_device("f0VMRgIBAQAAAAAAAAAAAA", false)

      assert {:ok, %DevicesStats{connected_devices: 0}} = Stats.get_devices_stats("autotestrealm")
    end
  end
end
