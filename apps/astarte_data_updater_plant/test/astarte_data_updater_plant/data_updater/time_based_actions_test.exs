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
end
