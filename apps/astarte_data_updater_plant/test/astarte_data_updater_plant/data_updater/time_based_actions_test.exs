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
  import Mox

  alias Astarte.Core.Device
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.DataUpdaterPlant.AMQPTestHelper
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

  describe "reload_device_triggers_on_expiry/2" do
    test "refreshes device triggers when expired and triggers are unchanged", %{
      realm: realm,
      encoded_device_id: encoded_device_id,
      device_id: device_id
    } do
      # Insert initial device state
      state =
        setup_device_triggers_state(
          realm,
          encoded_device_id,
          device_id,
          :device_trigger,
          @timestamp_us_x_10
        )

      assert [
               {
                 {^device_id, 1},
                 {
                   {:device_trigger, %DeviceTrigger{device_event_type: :DEVICE_CONNECTED}},
                   %AMQPTriggerTarget{routing_key: routing_key}
                 }
               }
             ] = state.volatile_triggers

      assert routing_key == AMQPTestHelper.events_routing_key()

      # Simulate expiration and refresh
      new_state = TimeBasedActions.reload_device_triggers_on_expiry(state, @timestamp2_us_x_10)

      assert new_state.last_device_triggers_refresh == @timestamp2_us_x_10
      assert new_state.volatile_triggers == state.volatile_triggers
    end

    test "refreshes data triggers when expired and triggers are unchanged", %{
      realm: realm,
      encoded_device_id: encoded_device_id,
      device_id: device_id
    } do
      # Insert initial device state
      state =
        setup_device_triggers_state(
          realm,
          encoded_device_id,
          device_id,
          :data_trigger,
          @timestamp_us_x_10
        )

      assert [
               {
                 {^device_id, 2},
                 {
                   {:data_trigger,
                    %DataTrigger{
                      interface_name: "com.test.SimpleStreamTest",
                      interface_major: 1,
                      data_trigger_type: :INCOMING_DATA,
                      match_path: "/0/value",
                      value_match_operator: :LESS_THAN,
                      known_value: _,
                      device_id: nil,
                      group_name: nil,
                      version: _,
                      __unknown_fields__: _
                    }},
                   %AMQPTriggerTarget{routing_key: routing_key}
                 }
               }
             ] = state.volatile_triggers

      assert routing_key == AMQPTestHelper.events_routing_key()

      # Simulate expiration and refresh
      new_state = TimeBasedActions.reload_device_triggers_on_expiry(state, @timestamp2_us_x_10)

      assert new_state.last_device_triggers_refresh == @timestamp2_us_x_10
      assert new_state.volatile_triggers == state.volatile_triggers
    end

    test "does not refresh device triggers when not expired", %{
      realm: realm,
      encoded_device_id: encoded_device_id,
      device_id: device_id
    } do
      # Insert initial device state
      state =
        setup_device_triggers_state(
          realm,
          encoded_device_id,
          device_id,
          :device_trigger,
          @timestamp_us_x_10
        )

      # Simulate no expiration
      timestamp2_us_x_10 = Database.make_timestamp("2025-05-14T14:05:32+00:00")

      new_state = TimeBasedActions.reload_device_triggers_on_expiry(state, timestamp2_us_x_10)

      assert new_state.last_device_triggers_refresh == state.last_device_triggers_refresh
      assert new_state.volatile_triggers == state.volatile_triggers
    end

    test "does not refresh device triggers when timestamp equals last refresh", %{
      realm: realm,
      encoded_device_id: encoded_device_id,
      device_id: device_id
    } do
      state =
        setup_device_triggers_state(
          realm,
          encoded_device_id,
          device_id,
          :device_trigger,
          @timestamp_us_x_10
        )

      # Use the same timestamp, should not refresh
      new_state = TimeBasedActions.reload_device_triggers_on_expiry(state, @timestamp_us_x_10)

      assert new_state.last_device_triggers_refresh == state.last_device_triggers_refresh
      assert new_state.volatile_triggers == state.volatile_triggers
    end

    test "refreshes device triggers to empty when no triggers are present in database", %{
      realm: realm,
      encoded_device_id: encoded_device_id,
      device_id: device_id
    } do
      # Insert initial device state
      Database.insert_device(device_id, realm)

      # No triggers installed
      DataUpdater.handle_connection(
        realm,
        encoded_device_id,
        "10.0.0.1",
        Database.gen_tracking_id(),
        @timestamp_us_x_10
      )

      state = DataUpdater.dump_state(realm, encoded_device_id)

      assert state.last_device_triggers_refresh == @timestamp_us_x_10
      assert state.volatile_triggers == []

      # Simulate expiration and refresh
      new_state = TimeBasedActions.reload_device_triggers_on_expiry(state, @timestamp2_us_x_10)

      assert new_state.last_device_triggers_refresh == @timestamp2_us_x_10
      assert new_state.volatile_triggers == []
    end

    test "adds new volatile triggers and keeps all after refresh", %{
      realm: realm,
      encoded_device_id: encoded_device_id,
      device_id: device_id
    } do
      # Insert initial device state
      state =
        setup_device_triggers_state(
          realm,
          encoded_device_id,
          device_id,
          :device_trigger,
          @timestamp_us_x_10
        )

      # Install additional data_trigger
      data_trigger_data =
        %SimpleTriggerContainer{
          simple_trigger: {
            :data_trigger,
            %DataTrigger{
              interface_name: "com.test.SimpleStreamTest",
              interface_major: 1,
              data_trigger_type: :INCOMING_DATA,
              match_path: "/0/value",
              value_match_operator: :LESS_THAN,
              known_value: Cyanide.encode!(%{v: 50})
            }
          }
        }
        |> SimpleTriggerContainer.encode()

      trigger_target_data =
        %TriggerTargetContainer{
          trigger_target: {
            :amqp_trigger_target,
            %AMQPTriggerTarget{
              routing_key: AMQPTestHelper.events_routing_key()
            }
          }
        }
        |> TriggerTargetContainer.encode()

      volatile_trigger_parent_id = :crypto.strong_rand_bytes(16)
      volatile_trigger_id = :crypto.strong_rand_bytes(16)

      assert :ok ==
               DataUpdater.handle_install_volatile_trigger(
                 realm,
                 encoded_device_id,
                 device_id,
                 2,
                 volatile_trigger_parent_id,
                 volatile_trigger_id,
                 data_trigger_data,
                 trigger_target_data
               )

      new_state = DataUpdater.dump_state(realm, encoded_device_id)

      assert Enum.count(new_state.volatile_triggers) == 2

      # Refresh device triggers
      refreshed_state =
        TimeBasedActions.reload_device_triggers_on_expiry(new_state, @timestamp2_us_x_10)

      assert Enum.count(refreshed_state.volatile_triggers) == 2
      assert refreshed_state.last_device_triggers_refresh > state.last_device_triggers_refresh
    end

    test "removes deleted volatile triggers after refresh", %{
      realm: realm,
      encoded_device_id: encoded_device_id,
      device_id: device_id
    } do
      Database.insert_device(device_id, realm)

      simple_trigger_data =
        %SimpleTriggerContainer{
          simple_trigger: {
            :device_trigger,
            %DeviceTrigger{
              device_event_type: :DEVICE_CONNECTED
            }
          }
        }
        |> SimpleTriggerContainer.encode()

      trigger_target_data =
        %TriggerTargetContainer{
          trigger_target: {
            :amqp_trigger_target,
            %AMQPTriggerTarget{
              routing_key: AMQPTestHelper.events_routing_key()
            }
          }
        }
        |> TriggerTargetContainer.encode()

      volatile_trigger_parent_id = :crypto.strong_rand_bytes(16)
      volatile_trigger_id = :crypto.strong_rand_bytes(16)

      assert DataUpdater.handle_install_volatile_trigger(
               realm,
               encoded_device_id,
               device_id,
               1,
               volatile_trigger_parent_id,
               volatile_trigger_id,
               simple_trigger_data,
               trigger_target_data
             ) == :ok

      assert DataUpdater.handle_delete_volatile_trigger(
               realm,
               encoded_device_id,
               volatile_trigger_id
             ) == :ok

      DataUpdater.handle_connection(
        realm,
        encoded_device_id,
        "10.0.0.1",
        Database.gen_tracking_id(),
        @timestamp_us_x_10
      )

      state = DataUpdater.dump_state(realm, encoded_device_id)

      new_state =
        TimeBasedActions.reload_device_triggers_on_expiry(
          state,
          @timestamp2_us_x_10
        )

      assert new_state.last_device_triggers_refresh == @timestamp2_us_x_10
      assert new_state.volatile_triggers == state.volatile_triggers
    end
  end

  describe "reload_device_deletion_status_on_expiry/2" do
    test "refreshes deletion status when expired and device is not being deleted", %{
      realm: realm,
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
      realm: realm,
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
           realm: realm,
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
      realm: realm,
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
           realm: realm,
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
      realm: realm,
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
      realm: realm,
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
    setup do
      realm = "autotestrealm#{System.unique_integer([:positive])}"
      Database.setup_realm_keyspace!(realm)

      on_exit(fn ->
        Database.teardown_realm_keyspace!(realm)
      end)

      {:ok, realm: realm}
    end

    test "refreshes datastream_maximum_storage_retention when expired and value is unchanged", %{
      realm: realm,
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
      realm: realm,
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
      realm: realm,
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
           realm: realm,
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

  defp setup_device_triggers_state(
         realm,
         encoded_device_id,
         device_id,
         trigger_type,
         timestamp,
         trigger_opts \\ []
       ) do
    trigger_data =
      case trigger_type do
        :device_trigger ->
          %SimpleTriggerContainer{
            simple_trigger: {
              :device_trigger,
              %DeviceTrigger{
                device_event_type: trigger_opts[:device_event_type] || :DEVICE_CONNECTED
              }
            }
          }

        :data_trigger ->
          %SimpleTriggerContainer{
            simple_trigger: {
              :data_trigger,
              %DataTrigger{
                interface_name: trigger_opts[:interface_name] || "com.test.SimpleStreamTest",
                interface_major: trigger_opts[:interface_major] || 1,
                data_trigger_type: trigger_opts[:data_trigger_type] || :INCOMING_DATA,
                match_path: trigger_opts[:match_path] || "/0/value",
                value_match_operator: trigger_opts[:value_match_operator] || :LESS_THAN,
                known_value: trigger_opts[:known_value] || Cyanide.encode!(%{v: 100})
              }
            }
          }
      end
      |> SimpleTriggerContainer.encode()

    trigger_target_data =
      %TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> TriggerTargetContainer.encode()

    volatile_trigger_parent_id = :crypto.strong_rand_bytes(16)
    volatile_trigger_id = :crypto.strong_rand_bytes(16)
    ref = if trigger_type == :data_trigger, do: 2, else: 1

    Database.insert_device(device_id, realm)

    :ok =
      DataUpdater.handle_install_volatile_trigger(
        realm,
        encoded_device_id,
        device_id,
        ref,
        volatile_trigger_parent_id,
        volatile_trigger_id,
        trigger_data,
        trigger_target_data
      )

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
