#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.DataUpdaterTest do
  use Astarte.Cases.Data
  use Astarte.Cases.AMQP

  import Mox
  import Astarte.Helpers.DataUpdater

  import Ecto.Query

  alias Astarte.Core.Device
  alias Astarte.Core.Triggers.SimpleEvents.DeviceConnectedEvent
  alias Astarte.Core.Triggers.SimpleEvents.DeviceDisconnectedEvent
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.DataAccess.Devices.Device, as: DeviceSchema
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataUpdaterPlant.AMQPTestHelper
  alias Astarte.DataUpdaterPlant.DatabaseTestHelper
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataAccess.Repo

  setup :verify_on_exit!

  setup_all %{realm_name: realm_name} do
    encoded_device_id = "f0VMRgIBAQAAAAAAAAAAAA"
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)
    received_msgs = 45000
    received_bytes = 4_500_000
    existing_introspection_map = %{"com.test.LCDMonitor" => 1, "com.test.SimpleStreamTest" => 1}

    insert_opts = [
      introspection: existing_introspection_map,
      total_received_msgs: received_msgs,
      total_received_bytes: received_bytes,
      groups: ["group1"]
    ]

    DatabaseTestHelper.insert_device(realm_name, device_id, insert_opts)
    test_process = self()

    Astarte.DataUpdaterPlant.RPC.VMQPlugin.ClientMock
    |> Mox.stub(:delete, fn %{realm_name: ^realm_name, device_id: ^encoded_device_id} ->
      send(test_process, :data_updater_message_received)
      :ok
    end)

    setup_data_updater(realm_name, encoded_device_id)

    %{
      device_id: device_id,
      encoded_device_id: encoded_device_id,
      received_msgs: received_msgs,
      received_bytes: received_bytes
    }
  end

  test "empty introspection is updated correctly", %{
    realm: realm,
    amqp_consumer: amqp_consumer,
    test_id: test_id
  } do
    AMQPTestHelper.clean_queue(amqp_consumer)

    keyspace_name = Realm.keyspace_name(realm)

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)
    new_introspection_map = %{"com.test.LCDMonitor" => 1, "com.test.SimpleStreamTest" => 1}
    new_introspection_string = "com.test.LCDMonitor:1:0;com.test.SimpleStreamTest:1:0"

    DatabaseTestHelper.insert_device(realm, device_id, groups: ["group2"])
    setup_data_updater(realm, encoded_device_id)

    volatile_parent_id = DatabaseTestHelper.fake_parent_trigger_id()
    volatile_trigger_id = DatabaseTestHelper.group2_device_connected_trigger_id()

    volatile_trigger_data =
      %SimpleTriggerContainer{
        simple_trigger: {:device_trigger, %DeviceTrigger{device_event_type: :DEVICE_CONNECTED}}
      }
      |> SimpleTriggerContainer.encode()

    volatile_target_data = generate_trigger_target(test_id)

    assert DataUpdater.handle_install_volatile_trigger(
             realm,
             encoded_device_id,
             device_id,
             1,
             volatile_parent_id,
             volatile_trigger_id,
             volatile_trigger_data,
             volatile_target_data
           ) == :ok

    timestamp_us_x_10 = make_timestamp("2017-12-09T14:00:32+00:00")
    timestamp_ms = div(timestamp_us_x_10, 10_000)

    DataUpdater.handle_connection(
      realm,
      encoded_device_id,
      "10.0.0.1",
      gen_tracking_id(),
      timestamp_us_x_10
    )

    DataUpdater.dump_state(realm, encoded_device_id)

    {conn_event, conn_headers, _metadata} = AMQPTestHelper.wait_and_get_message(amqp_consumer)
    assert conn_headers["x_astarte_event_type"] == "device_connected_event"
    assert conn_headers["x_astarte_realm"] == realm
    assert conn_headers["x_astarte_device_id"] == encoded_device_id

    assert :uuid.string_to_uuid(conn_headers["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(conn_headers["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.group2_device_connected_trigger_id()

    assert SimpleEvent.decode(conn_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event:
               {:device_connected_event, %DeviceConnectedEvent{device_ip_address: "10.0.0.1"}},
             timestamp: timestamp_ms,
             parent_trigger_id: volatile_parent_id,
             realm: realm,
             simple_trigger_id: volatile_trigger_id
           }

    device_introspection_query =
      from d in DeviceSchema,
        prefix: ^keyspace_name,
        where: d.device_id == ^device_id,
        select: d.introspection

    old_device_introspection = Repo.one(device_introspection_query)

    assert old_device_introspection == %{}

    timestamp_us_x_10 = make_timestamp("2017-10-09T14:00:32+00:00")

    DataUpdater.handle_introspection(
      realm,
      encoded_device_id,
      new_introspection_string,
      gen_tracking_id(),
      timestamp_us_x_10
    )

    DataUpdater.dump_state(realm, encoded_device_id)

    new_device_introspection = Repo.one(device_introspection_query)

    assert new_device_introspection == new_introspection_map

    assert AMQPTestHelper.awaiting_messages_count(amqp_consumer) == 0
  end

  test "test introspection with interface update", %{
    realm: realm,
    amqp_consumer: amqp_consumer
  } do
    AMQPTestHelper.clean_queue(amqp_consumer)

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    DatabaseTestHelper.insert_device(realm, device_id)
    setup_data_updater(realm, encoded_device_id)

    DataUpdater.handle_connection(
      realm,
      encoded_device_id,
      "10.0.0.1",
      gen_tracking_id(),
      make_timestamp("2017-12-09T14:00:32+00:00")
    )

    new_introspection_string = "com.test.LCDMonitor:1:0;com.test.SimpleStreamTest:1:0"

    DataUpdater.handle_introspection(
      realm,
      encoded_device_id,
      new_introspection_string,
      gen_tracking_id(),
      make_timestamp("2017-10-09T14:00:32+00:00")
    )

    DataUpdater.dump_state(realm, encoded_device_id)
    assert DatabaseTestHelper.fetch_old_introspection(realm, device_id) == {:ok, %{}}

    new_introspection_string = "com.test.LCDMonitor:2:0;com.test.SimpleStreamTest:1:0"

    DataUpdater.handle_introspection(
      realm,
      encoded_device_id,
      new_introspection_string,
      gen_tracking_id(),
      make_timestamp("2017-10-09T15:00:32+00:00")
    )

    DataUpdater.dump_state(realm, encoded_device_id)
    DatabaseTestHelper.fetch_old_introspection(realm, device_id)

    assert DatabaseTestHelper.fetch_old_introspection(realm, device_id) ==
             {:ok, %{{"com.test.LCDMonitor", 1} => 0}}

    new_introspection_string = "com.test.LCDMonitor:2:0"

    DataUpdater.handle_introspection(
      realm,
      encoded_device_id,
      new_introspection_string,
      gen_tracking_id(),
      make_timestamp("2017-10-09T16:00:32+00:00")
    )

    DataUpdater.dump_state(realm, encoded_device_id)

    assert DatabaseTestHelper.fetch_old_introspection(realm, device_id) ==
             {:ok, %{{"com.test.LCDMonitor", 1} => 0, {"com.test.SimpleStreamTest", 1} => 0}}
  end

  test "fails to install volatile trigger on missing device", %{
    realm: realm,
    amqp_consumer: amqp_consumer,
    test_id: test_id
  } do
    AMQPTestHelper.clean_queue(amqp_consumer)

    # Install a volatile device test trigger
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
            routing_key: AMQPTestHelper.events_routing_key(test_id)
          }
        }
      }
      |> TriggerTargetContainer.encode()

    volatile_trigger_parent_id = :crypto.strong_rand_bytes(16)
    volatile_trigger_id = :crypto.strong_rand_bytes(16)

    fail_encoded_device_id = "f0VMRgIBAQBBBBBBBBBBBB"
    {:ok, fail_device_id} = Device.decode_device_id(fail_encoded_device_id)

    assert DataUpdater.handle_install_volatile_trigger(
             realm,
             fail_encoded_device_id,
             fail_device_id,
             1,
             volatile_trigger_parent_id,
             volatile_trigger_id,
             simple_trigger_data,
             trigger_target_data
           ) == {:error, :device_does_not_exist}
  end

  test "fails to delete volatile trigger on missing device", %{
    realm: realm,
    amqp_consumer: amqp_consumer
  } do
    AMQPTestHelper.clean_queue(amqp_consumer)

    volatile_trigger_id = :crypto.strong_rand_bytes(16)

    fail_encoded_device_id = "f0VMRgIBAQBBBBBBBBBBBB"
    {:ok, _fail_device_id} = Device.decode_device_id(fail_encoded_device_id)

    assert DataUpdater.handle_delete_volatile_trigger(
             realm,
             fail_encoded_device_id,
             volatile_trigger_id
           ) == {:error, :device_does_not_exist}
  end

  test "heartbeat message of type internal is correctly handled", %{
    realm: realm,
    amqp_consumer: amqp_consumer
  } do
    alias Astarte.DataUpdaterPlant.DataUpdater.State

    AMQPTestHelper.clean_queue(amqp_consumer)

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    DatabaseTestHelper.insert_device(realm, device_id)
    setup_data_updater(realm, encoded_device_id)

    timestamp_us_x_10 = make_timestamp("2017-12-09T14:00:32+00:00")

    # Make sure a process for the device exists
    DataUpdater.handle_connection(
      realm,
      encoded_device_id,
      "10.0.0.1",
      gen_tracking_id(),
      timestamp_us_x_10
    )

    heartbeat_timestamp = make_timestamp("2023-05-12T18:05:32+00:00")

    DataUpdater.handle_internal(
      realm,
      encoded_device_id,
      "/heartbeat",
      "",
      gen_tracking_id(),
      heartbeat_timestamp
    )

    assert %State{last_seen_message: ^heartbeat_timestamp} =
             DataUpdater.dump_state(realm, encoded_device_id)
  end

  # TODO remove this when all heartbeats will be moved to internal
  test "heartbeat message of type heartbeat is correctly handled", %{
    realm: realm,
    amqp_consumer: amqp_consumer
  } do
    alias Astarte.DataUpdaterPlant.DataUpdater.State

    AMQPTestHelper.clean_queue(amqp_consumer)

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    DatabaseTestHelper.insert_device(realm, device_id)
    setup_data_updater(realm, encoded_device_id)

    timestamp_us_x_10 = make_timestamp("2017-12-09T14:00:32+00:00")

    # Make sure a process for the device exists
    DataUpdater.handle_connection(
      realm,
      encoded_device_id,
      "10.0.0.1",
      gen_tracking_id(),
      timestamp_us_x_10
    )

    heartbeat_timestamp = make_timestamp("2023-05-12T18:05:32+00:00")

    DataUpdater.handle_heartbeat(
      realm,
      encoded_device_id,
      gen_tracking_id(),
      heartbeat_timestamp
    )

    assert %State{last_seen_message: ^heartbeat_timestamp} =
             DataUpdater.dump_state(realm, encoded_device_id)
  end

  setup [:set_mox_from_context, :verify_on_exit!]

  test "a disconnected device does not generate a disconnection trigger", %{
    realm: realm,
    amqp_consumer: amqp_consumer,
    test_id: test_id
  } do
    AMQPTestHelper.clean_queue(amqp_consumer)

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    DatabaseTestHelper.insert_device(realm, device_id)
    setup_data_updater(realm, encoded_device_id)

    timestamp_us_x_10 = make_timestamp("2017-12-09T14:00:32+00:00")
    timestamp_ms = div(timestamp_us_x_10, 10_000)

    volatile_trigger_parent_id = :crypto.strong_rand_bytes(16)
    volatile_trigger_id = :crypto.strong_rand_bytes(16)

    assert DataUpdater.handle_install_volatile_trigger(
             realm,
             encoded_device_id,
             device_id,
             1,
             volatile_trigger_parent_id,
             volatile_trigger_id,
             generate_disconnection_trigger_data(),
             generate_trigger_target(test_id)
           ) == :ok

    DataUpdater.handle_disconnection(
      realm,
      encoded_device_id,
      gen_tracking_id(),
      timestamp_us_x_10
    )

    # Receive the first disconnection trigger
    {event, headers, _metadata} = AMQPTestHelper.wait_and_get_message(amqp_consumer)
    assert headers["x_astarte_event_type"] == "device_disconnected_event"
    assert headers["x_astarte_realm"] == realm
    assert headers["x_astarte_device_id"] == encoded_device_id

    assert :uuid.string_to_uuid(headers["x_astarte_parent_trigger_id"]) ==
             volatile_trigger_parent_id

    assert :uuid.string_to_uuid(headers["x_astarte_simple_trigger_id"]) == volatile_trigger_id

    assert SimpleEvent.decode(event) == %SimpleEvent{
             device_id: encoded_device_id,
             event: {
               :device_disconnected_event,
               %DeviceDisconnectedEvent{}
             },
             parent_trigger_id: volatile_trigger_parent_id,
             timestamp: timestamp_ms,
             realm: realm,
             simple_trigger_id: volatile_trigger_id
           }

    DataUpdater.handle_disconnection(
      realm,
      encoded_device_id,
      gen_tracking_id(),
      timestamp_us_x_10
    )

    # The second disconnection trigger is not sent
    assert AMQPTestHelper.awaiting_messages_count(amqp_consumer) == 0
  end

  defp generate_disconnection_trigger_data() do
    %SimpleTriggerContainer{
      simple_trigger: {
        :device_trigger,
        %DeviceTrigger{
          device_event_type: :DEVICE_DISCONNECTED
        }
      }
    }
    |> SimpleTriggerContainer.encode()
  end

  # defp generate_trigger_target() do
  #   generate_trigger_target(nil)
  # end

  defp generate_trigger_target(id) do
    %TriggerTargetContainer{
      trigger_target: {
        :amqp_trigger_target,
        %AMQPTriggerTarget{
          routing_key: AMQPTestHelper.events_routing_key(id),
          exchange: AMQPTestHelper.events_exchange_name(id)
        }
      }
    }
    |> TriggerTargetContainer.encode()
  end
end
