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
  use Astarte.Cases.Data, async: true
  import Mox
  import Astarte.Helpers.DataUpdater

  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.TimeBasedActions
  alias Astarte.Helpers.Database

  @timestamp_us_x_10 Database.make_timestamp("2025-05-14T14:00:32+00:00")
  @timestamp2_us_x_10 Database.make_timestamp("2025-05-14T14:10:32+00:00")
  @interface_lifespan_decimicroseconds 60 * 10 * 1000 * 10_000

  setup do
    device_id = Database.random_device_id()
    encoded_device_id = Device.encode_device_id(device_id)
    {:ok, device_id: device_id, encoded_device_id: encoded_device_id}
  end

  describe "purge_expired_interfaces/2" do
    test "removes all interfaces when all are expired", %{
      realm_name: realm,
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
      realm_name: realm,
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
      realm_name: realm,
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
      realm_name: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      # Insert initial device state
      insert_device_and_start_data_updater(realm, device_id, introspection: %{})

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

  describe "reload_device_deletion_status_on_expiry/2" do
    test "refreshes deletion status when expired and device is not being deleted", %{
      realm_name: realm,
      encoded_device_id: encoded_device_id,
      device_id: device_id
    } do
      # Insert initial device state
      state = setup_device_state(realm, device_id, encoded_device_id, [])

      assert state.last_deletion_in_progress_refresh == @timestamp_us_x_10
      assert state.discard_messages == false

      # Simulate expiration and refresh
      new_state =
        TimeBasedActions.reload_device_deletion_status_on_expiry(state, @timestamp2_us_x_10)

      assert new_state.last_deletion_in_progress_refresh == @timestamp2_us_x_10
      assert new_state.discard_messages == false
    end

    test "does not refresh deletion status if not expired", %{
      realm_name: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      # Insert initial device state
      state = setup_device_state(realm, device_id, encoded_device_id, [])

      assert state.last_deletion_in_progress_refresh == @timestamp_us_x_10
      assert state.discard_messages == false

      timestamp2_us_x_10 = Database.make_timestamp("2025-05-14T14:05:32+00:00")

      new_state =
        TimeBasedActions.reload_device_deletion_status_on_expiry(state, timestamp2_us_x_10)

      assert new_state.last_deletion_in_progress_refresh == @timestamp_us_x_10
      assert new_state.discard_messages == false
    end

    test "does not stop DataUpdater process if deletion is in progress but not acked and not expired",
         %{
           realm_name: realm,
           encoded_device_id: encoded_device_id,
           device_id: device_id
         } do
      # Insert initial device state
      state = setup_device_state(realm, device_id, encoded_device_id, [])

      assert state.last_deletion_in_progress_refresh == @timestamp_us_x_10
      assert state.discard_messages == false

      Database.insert_deletion_in_progress(device_id, realm)

      timestamp2_us_x_10 = Database.make_timestamp("2025-05-14T14:05:32+00:00")

      new_state =
        TimeBasedActions.reload_device_deletion_status_on_expiry(state, timestamp2_us_x_10)

      assert new_state.last_deletion_in_progress_refresh == @timestamp_us_x_10
      assert new_state.discard_messages == false
      assert new_state.connected == true
    end

    test "disconnects and discards messages when deletion is acked and expired", %{
      realm_name: realm,
      encoded_device_id: encoded_device_id,
      device_id: device_id
    } do
      # Insert initial device state
      state = setup_device_state(realm, device_id, encoded_device_id, [])

      assert state.last_deletion_in_progress_refresh == @timestamp_us_x_10
      assert state.discard_messages == false

      Database.insert_deletion_in_progress(device_id, realm)

      Astarte.DataUpdaterPlant.RPC.VMQPlugin.ClientMock
      |> expect(:delete, fn data ->
        assert %{realm_name: ^realm, device_id: ^encoded_device_id} = data

        :ok
      end)

      new_state =
        TimeBasedActions.reload_device_deletion_status_on_expiry(
          state,
          @timestamp2_us_x_10
        )

      assert new_state.last_deletion_in_progress_refresh == @timestamp2_us_x_10
      assert new_state.discard_messages == true
      assert new_state.connected == false
    end

    test "disconnects and discards messages when deletion is acked, expired, and device is already disconnected",
         %{
           realm_name: realm,
           encoded_device_id: encoded_device_id,
           device_id: device_id
         } do
      # Insert initial device state
      state = setup_device_state(realm, device_id, encoded_device_id, [])

      assert state.last_deletion_in_progress_refresh == @timestamp_us_x_10
      assert state.discard_messages == false

      Database.insert_deletion_in_progress(device_id, realm)

      # Not found means it was already disconnected, succeed anyway
      Astarte.DataUpdaterPlant.RPC.VMQPlugin.ClientMock
      |> expect(:delete, fn data ->
        assert %{realm_name: ^realm, device_id: ^encoded_device_id} = data

        {:error, :not_found}
      end)

      new_state =
        TimeBasedActions.reload_device_deletion_status_on_expiry(
          state,
          @timestamp2_us_x_10
        )

      assert new_state.last_deletion_in_progress_refresh == @timestamp2_us_x_10
      assert new_state.discard_messages == true
      assert new_state.connected == false
    end

    test "raises MatchError if deletion returns error", %{
      realm_name: realm,
      encoded_device_id: encoded_device_id,
      device_id: device_id
    } do
      # Insert initial device state
      state = setup_device_state(realm, device_id, encoded_device_id, [])

      assert state.last_deletion_in_progress_refresh == @timestamp_us_x_10
      assert state.discard_messages == false
      assert state.connected == true

      Database.insert_deletion_in_progress(device_id, realm)

      # Simulate VMQPlugin.delete returning an error
      Astarte.DataUpdaterPlant.RPC.VMQPlugin.ClientMock
      |> expect(:delete, fn data ->
        assert %{realm_name: ^realm, device_id: ^encoded_device_id} = data
        {:error, :bad_request}
      end)

      assert_raise MatchError, fn ->
        TimeBasedActions.reload_device_deletion_status_on_expiry(
          state,
          @timestamp2_us_x_10
        )
      end
    end

    test "does not start device deletion if check_device_deletion_in_progress returns error", %{
      realm_name: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      # Insert initial device state
      state = setup_device_state(realm, device_id, encoded_device_id, [])

      # Simulate error scenario: update the state to use the nonexistent realm
      nonexistent_realm = "nonexistentrealm#{System.unique_integer([:positive])}"
      state = %{state | realm: nonexistent_realm}

      # Verify state behavior: only timestamp is updated, no deletion triggered
      new_state =
        TimeBasedActions.reload_device_deletion_status_on_expiry(
          state,
          @timestamp2_us_x_10
        )

      # State should only have updated last_deletion_in_progress_refresh
      assert new_state.last_deletion_in_progress_refresh == @timestamp2_us_x_10
      assert new_state.discard_messages == false
      assert new_state.connected == true
    end
  end

  describe "reload_datastream_maximum_storage_retention_on_expiry/2" do
    @describetag timeout: 120_000
    setup do
      %{realm_names: [realm_name]} = setup_instance()

      {:ok, realm_name: realm_name}
    end

    test "refreshes datastream_maximum_storage_retention when expired and value is unchanged", %{
      realm_name: realm,
      encoded_device_id: encoded_device_id,
      device_id: device_id
    } do
      # Insert initial device state
      state = setup_device_state(realm, device_id, encoded_device_id, [])

      assert state.datastream_maximum_storage_retention == nil
      assert state.last_datastream_maximum_retention_refresh == @timestamp_us_x_10

      # Simulate expiration and refresh
      new_state =
        TimeBasedActions.reload_datastream_maximum_storage_retention_on_expiry(
          state,
          @timestamp2_us_x_10
        )

      assert new_state.datastream_maximum_storage_retention == nil
      assert new_state.last_datastream_maximum_retention_refresh == @timestamp2_us_x_10
    end

    test "refreshes datastream_maximum_storage_retention when expired and value is updated", %{
      realm_name: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      # Insert initial device state
      state = setup_device_state(realm, device_id, encoded_device_id, [])

      assert state.datastream_maximum_storage_retention == nil
      assert state.last_datastream_maximum_retention_refresh == @timestamp_us_x_10

      # Update value in the database, simulate expiration and refresh
      Database.insert_datastream_maximum_storage_retention!(realm, 60)

      new_state =
        TimeBasedActions.reload_datastream_maximum_storage_retention_on_expiry(
          state,
          @timestamp2_us_x_10
        )

      assert new_state.datastream_maximum_storage_retention == 60
      assert new_state.last_datastream_maximum_retention_refresh == @timestamp2_us_x_10
    end

    test "does not refresh datastream_maximum_storage_retention when not expired", %{
      realm_name: realm,
      device_id: device_id,
      encoded_device_id: encoded_device_id
    } do
      # Insert initial device state
      state = setup_device_state(realm, device_id, encoded_device_id, [])

      Database.insert_datastream_maximum_storage_retention!(realm, 120)

      timestamp2_us_x_10 = Database.make_timestamp("2025-05-14T14:05:32+00:00")

      new_state =
        TimeBasedActions.reload_datastream_maximum_storage_retention_on_expiry(
          state,
          timestamp2_us_x_10
        )

      assert new_state.datastream_maximum_storage_retention == nil
      assert new_state.last_datastream_maximum_retention_refresh == @timestamp_us_x_10
    end

    test "does not refresh datastream_maximum_storage_retention when timestamp equals last refresh",
         %{
           realm_name: realm,
           device_id: device_id,
           encoded_device_id: encoded_device_id
         } do
      # Insert initial device state
      state = setup_device_state(realm, device_id, encoded_device_id, [])

      Database.insert_datastream_maximum_storage_retention!(realm, 180)

      new_state =
        TimeBasedActions.reload_datastream_maximum_storage_retention_on_expiry(
          state,
          @timestamp_us_x_10
        )

      assert new_state.datastream_maximum_storage_retention == nil
      assert new_state.last_datastream_maximum_retention_refresh == @timestamp_us_x_10
    end

    test "does not update datastream_maximum_storage_retention if fetch returns :error",
         %{
           realm_name: realm,
           device_id: device_id,
           encoded_device_id: encoded_device_id
         } do
      # Insert initial device state
      state = setup_device_state(realm, device_id, encoded_device_id, [])

      # Simulate error scenario: update the state to use a nonexistent realm
      nonexistent_realm = "nonexistentrealm#{System.unique_integer([:positive])}"
      state = %{state | realm: nonexistent_realm}

      new_state =
        TimeBasedActions.reload_datastream_maximum_storage_retention_on_expiry(
          state,
          @timestamp2_us_x_10
        )

      # State should remain unchanged
      assert new_state.last_datastream_maximum_retention_refresh ==
               state.last_datastream_maximum_retention_refresh

      assert new_state.datastream_maximum_storage_retention ==
               state.datastream_maximum_storage_retention
    end
  end

  defp setup_device_state(
         realm,
         device_id,
         encoded_device_id,
         insert_opts,
         timestamp \\ @timestamp_us_x_10
       ) do
    insert_device_and_start_data_updater(realm, device_id, insert_opts)

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
    insert_device_and_start_data_updater(realm, device_id, introspection: introspection_map)

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

  defp insert_device_and_start_data_updater(realm_name, device_id, params) do
    encoded_device_id = Device.encode_device_id(device_id)
    Database.insert_device(device_id, realm_name, params)

    setup_data_updater(realm_name, encoded_device_id)
    :ok
  end
end
