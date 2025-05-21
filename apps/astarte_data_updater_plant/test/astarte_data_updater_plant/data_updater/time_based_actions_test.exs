#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.TimeBasedActionsTest do
  use ExUnit.Case, async: true

  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.TimeBasedActions
  alias Astarte.Helpers.Database

  @timestamp_us_x_10 Database.make_timestamp("2025-05-14T14:00:32+00:00")
  @timestamp2_us_x_10 Database.make_timestamp("2025-05-14T14:10:32+00:00")
  @interface_lifespan_decimicroseconds 60 * 10 * 1000 * 10000

  setup_all do
    realm = "autotestrealm#{System.unique_integer([:positive])}"
    Database.setup!(realm)
    on_exit(fn -> Database.teardown!(realm) end)
    {:ok, realm: realm}
  end

  setup %{realm: realm} do
    device_id = Database.random_device_id()
    encoded_device_id = Device.encode_device_id(device_id)
    {:ok, device_id: device_id, encoded_device_id: encoded_device_id, realm: realm}
  end

  describe "reload_groups_on_expiry/2" do
    test "refreshes groups when expired but groups are unchanged", %{
      realm: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      # Insert initial device state
      insert_opts = [groups: ["group1"]]
      state = setup_device_state(realm, device_id, encoded_device_id, insert_opts)

      assert state.groups == ["group1"]
      assert state.last_groups_refresh == @timestamp_us_x_10

      # Simulate expiration and refresh
      new_state = TimeBasedActions.reload_groups_on_expiry(state, @timestamp2_us_x_10)

      assert new_state.groups == ["group1"]
      assert new_state.last_groups_refresh == @timestamp2_us_x_10
    end

    test "refreshes groups when expired and database groups have changed", %{
      realm: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      # Insert initial device state
      insert_opts = [groups: ["group1"]]
      state = setup_device_state(realm, device_id, encoded_device_id, insert_opts)

      assert state.groups == ["group1"]
      assert state.last_groups_refresh == @timestamp_us_x_10

      # Update groups in the database, simulate expiration and refresh
      Database.update_device(device_id, realm, groups: ["group1", "group2"])
      new_state = TimeBasedActions.reload_groups_on_expiry(state, @timestamp2_us_x_10)

      assert new_state.groups == ["group1", "group2"]
      assert new_state.last_groups_refresh == @timestamp2_us_x_10
    end

    test "refreshes groups with multiple updates in database", %{
      realm: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      # Insert initial device state
      insert_opts = [groups: ["group1"]]
      state = setup_device_state(realm, device_id, encoded_device_id, insert_opts)

      assert state.groups == ["group1"]
      assert state.last_groups_refresh == @timestamp_us_x_10

      # Update groups in the database, simulate expiration and refresh
      Database.update_device(device_id, realm, groups: ["group2", "group3"])
      new_state = TimeBasedActions.reload_groups_on_expiry(state, @timestamp2_us_x_10)

      assert new_state.groups == ["group2", "group3"]
      assert new_state.last_groups_refresh == @timestamp2_us_x_10
    end

    test "refreshes groups to empty when database groups are removed", %{
      realm: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      # Insert initial device state
      insert_opts = [groups: ["group1"]]
      state = setup_device_state(realm, device_id, encoded_device_id, insert_opts)

      assert state.groups == ["group1"]
      assert state.last_groups_refresh == @timestamp_us_x_10

      # Remove groups in the database, simulate expiration and refresh
      Database.update_device(device_id, realm, groups: [])
      new_state = TimeBasedActions.reload_groups_on_expiry(state, @timestamp2_us_x_10)

      assert new_state.groups == []
      assert new_state.last_groups_refresh == @timestamp2_us_x_10
    end

    test "does not refresh groups when not expired", %{
      realm: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      # Insert initial device state
      insert_opts = [groups: ["group1"]]
      state = setup_device_state(realm, device_id, encoded_device_id, insert_opts)

      assert state.groups == ["group1"]
      assert state.last_groups_refresh == @timestamp_us_x_10

      # Simulate no expiration
      timestamp2_us_x_10 = Database.make_timestamp("2025-05-14T14:05:32+00:00")
      new_state = TimeBasedActions.reload_groups_on_expiry(state, timestamp2_us_x_10)

      assert new_state.groups == state.groups
      assert new_state.last_groups_refresh == state.last_groups_refresh
    end

    test "does not refresh groups when timestamp equals last refresh", %{
      realm: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      # Insert initial device state
      insert_opts = [groups: ["group1"]]
      state = setup_device_state(realm, device_id, encoded_device_id, insert_opts)

      # Use the same timestamp, should not refresh
      new_state = TimeBasedActions.reload_groups_on_expiry(state, @timestamp_us_x_10)

      assert new_state.groups == state.groups
      assert new_state.last_groups_refresh == state.last_groups_refresh
    end
  end

  describe "purge_expired_interfaces/2" do
    test "removes all interfaces when all are expired", %{
      realm: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      # Insert initial device state
      state =
        setup_device_interfaces_state(
          %{"com.test.LCDMonitor" => 1},
          [{"com.test.LCDMonitor", "/weekSchedule/3/start", 1, @timestamp_us_x_10}],
          realm,
          device_id,
          encoded_device_id
        )

      assert Map.has_key?(state.interfaces, "com.test.LCDMonitor")
      assert Map.values(state.interface_ids_to_name) == ["com.test.LCDMonitor"]

      assert state.interfaces_by_expiry == [
               {@timestamp_us_x_10 + @interface_lifespan_decimicroseconds, "com.test.LCDMonitor"}
             ]

      # Simulate expiration and refresh
      new_state = TimeBasedActions.purge_expired_interfaces(state, @timestamp2_us_x_10)

      assert new_state.interfaces == %{}
      assert new_state.interface_ids_to_name == %{}
      assert new_state.interfaces_by_expiry == []
      assert new_state.mappings == %{}
    end

    test "removes only expired interfaces and keeps non-expired ones", %{
      realm: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      timestamp = Database.make_timestamp("2025-05-14T14:05:32+00:00")

      # Insert initial device state
      state =
        setup_device_interfaces_state(
          %{"com.test.LCDMonitor" => 1, "com.test.SimpleStreamTest" => 1},
          [
            {"com.test.LCDMonitor", "/weekSchedule/3/start", 1, @timestamp_us_x_10},
            {"com.test.SimpleStreamTest", "/0/value", 5, timestamp}
          ],
          realm,
          device_id,
          encoded_device_id
        )

      assert Map.keys(state.interfaces) |> Enum.sort() == [
               "com.test.LCDMonitor",
               "com.test.SimpleStreamTest"
             ]

      assert Map.values(state.interface_ids_to_name) |> Enum.sort() == [
               "com.test.LCDMonitor",
               "com.test.SimpleStreamTest"
             ]

      assert state.interfaces_by_expiry == [
               {@timestamp_us_x_10 + @interface_lifespan_decimicroseconds, "com.test.LCDMonitor"},
               {timestamp + @interface_lifespan_decimicroseconds, "com.test.SimpleStreamTest"}
             ]

      # Simulate expiration and refresh
      new_state = TimeBasedActions.purge_expired_interfaces(state, @timestamp2_us_x_10)

      assert Map.keys(new_state.interfaces) == ["com.test.SimpleStreamTest"]
      assert Map.values(new_state.interface_ids_to_name) == ["com.test.SimpleStreamTest"]

      assert new_state.interfaces_by_expiry == [
               {timestamp + @interface_lifespan_decimicroseconds, "com.test.SimpleStreamTest"}
             ]
    end

    test "does not remove interfaces if none are expired", %{
      realm: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      state =
        setup_device_interfaces_state(
          %{"com.test.LCDMonitor" => 1},
          [{"com.test.LCDMonitor", "/weekSchedule/3/start", 1, @timestamp_us_x_10}],
          realm,
          device_id,
          encoded_device_id
        )

      assert Map.has_key?(state.interfaces, "com.test.LCDMonitor")
      assert Map.values(state.interface_ids_to_name) == ["com.test.LCDMonitor"]

      assert state.interfaces_by_expiry == [
               {@timestamp_us_x_10 + @interface_lifespan_decimicroseconds, "com.test.LCDMonitor"}
             ]

      # Simulate not expired
      timestamp2_us_x_10 = Database.make_timestamp("2025-05-14T14:05:32+00:00")

      new_state = TimeBasedActions.purge_expired_interfaces(state, timestamp2_us_x_10)

      assert new_state.interfaces == state.interfaces
      assert new_state.interface_ids_to_name == state.interface_ids_to_name
      assert new_state.interfaces_by_expiry == state.interfaces_by_expiry
      assert new_state.mappings == state.mappings
    end

    test "handles empty interfaces state without errors", %{
      realm: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      # Insert initial device state
      Database.insert_device(device_id, realm, introspection: %{})

      state = DataUpdater.dump_state(realm, encoded_device_id)

      assert state.interfaces == %{}
      assert state.interface_ids_to_name == %{}
      assert state.interfaces_by_expiry == []
      assert state.mappings == %{}

      # Simulate expiration and refresh
      new_state = TimeBasedActions.purge_expired_interfaces(state, @timestamp_us_x_10)

      assert new_state.interfaces == state.interfaces
      assert new_state.interface_ids_to_name == state.interface_ids_to_name
      assert new_state.interfaces_by_expiry == state.interfaces_by_expiry
      assert new_state.mappings == state.mappings
    end
  end

  defp setup_device_state(
         realm,
         device_id,
         encoded_device_id,
         insert_opts,
         timestamp \\ @timestamp_us_x_10
       ) do
    Database.insert_device(device_id, realm, insert_opts)

    DataUpdater.handle_connection(
      realm,
      encoded_device_id,
      "10.0.0.1",
      Database.gen_tracking_id(),
      timestamp
    )

    DataUpdater.dump_state(realm, encoded_device_id)
  end

  defp setup_device_interfaces_state(
         introspection_map,
         interface_data,
         realm,
         device_id,
         encoded_device_id,
         timestamp \\ @timestamp_us_x_10
       ) do
    Database.insert_device(device_id, realm, introspection: introspection_map)

    Enum.each(interface_data, fn {interface, path, value, ts} ->
      DataUpdater.handle_data(
        realm,
        encoded_device_id,
        interface,
        path,
        Cyanide.encode!(%{"v" => value}),
        Database.gen_tracking_id(),
        ts || timestamp
      )
    end)

    DataUpdater.dump_state(realm, encoded_device_id)
  end
end
