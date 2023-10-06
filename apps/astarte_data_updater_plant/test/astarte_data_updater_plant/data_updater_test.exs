#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
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
  use ExUnit.Case
  import Mox

  alias Astarte.Core.Device
  alias Astarte.Core.Triggers.SimpleEvents.DeviceConnectedEvent
  alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent
  alias Astarte.Core.Triggers.SimpleEvents.PathRemovedEvent
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Triggers.SimpleEvents.ValueChangeAppliedEvent
  alias Astarte.Core.Triggers.SimpleEvents.IncomingIntrospectionEvent
  alias Astarte.Core.Triggers.SimpleEvents.InterfaceAddedEvent
  alias Astarte.Core.Triggers.SimpleEvents.InterfaceRemovedEvent
  alias Astarte.Core.Triggers.SimpleEvents.InterfaceMinorUpdatedEvent
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.DataAccess.Database
  alias Astarte.DataUpdaterPlant.AMQPTestHelper
  alias Astarte.DataUpdaterPlant.DatabaseTestHelper
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.Core.CQLUtils
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult
  alias Astarte.RPC.Protocol.VMQ.Plugin, as: Protocol

  alias Astarte.RPC.Protocol.VMQ.Plugin.{
    Call,
    Delete,
    GenericOkReply,
    Disconnect,
    Reply
  }

  @vmq_plugin_destination Protocol.amqp_queue()
  @encoded_generic_ok_reply %Reply{reply: {:generic_ok_reply, %GenericOkReply{}}}
                            |> Reply.encode()

  setup_all do
    {:ok, _client} = Astarte.DataUpdaterPlant.DatabaseTestHelper.create_test_keyspace()
    {:ok, _pid} = AMQPTestHelper.start_link()

    on_exit(fn ->
      Astarte.DataUpdaterPlant.DatabaseTestHelper.destroy_local_test_keyspace()
    end)
  end

  test "simple flow" do
    AMQPTestHelper.clean_queue()

    realm = "autotestrealm"
    encoded_device_id = "f0VMRgIBAQAAAAAAAAAAAA"
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    received_msgs = 45000
    received_bytes = 4_500_000
    existing_introspection_map = %{"com.test.LCDMonitor" => 1, "com.test.SimpleStreamTest" => 1}
    existing_introspection_string = "com.test.LCDMonitor:1:0;com.test.SimpleStreamTest:1:0"

    insert_opts = [
      introspection: existing_introspection_map,
      total_received_msgs: received_msgs,
      total_received_bytes: received_bytes,
      groups: ["group1"]
    ]

    DatabaseTestHelper.insert_device(device_id, insert_opts)

    {:ok, db_client} = Database.connect(realm: realm)

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

    timestamp_us_x_10 = make_timestamp("2017-10-09T14:00:32+00:00")
    timestamp_ms = div(timestamp_us_x_10, 10_000)

    DataUpdater.handle_connection(
      realm,
      encoded_device_id,
      "10.0.0.1",
      gen_tracking_id(),
      timestamp_us_x_10
    )

    DataUpdater.dump_state(realm, encoded_device_id)
    {conn_event, conn_headers, _metadata} = AMQPTestHelper.wait_and_get_message()
    assert conn_headers["x_astarte_event_type"] == "device_connected_event"
    assert conn_headers["x_astarte_realm"] == realm
    assert conn_headers["x_astarte_device_id"] == encoded_device_id

    assert :uuid.string_to_uuid(conn_headers["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(conn_headers["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.group1_device_connected_trigger_id()

    assert SimpleEvent.decode(conn_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event: {
               :device_connected_event,
               %DeviceConnectedEvent{
                 device_ip_address: "10.0.0.1"
               }
             },
             timestamp: timestamp_ms,
             parent_trigger_id: DatabaseTestHelper.fake_parent_trigger_id(),
             realm: realm,
             simple_trigger_id: DatabaseTestHelper.group1_device_connected_trigger_id()
           }

    {conn_event, conn_headers, _metadata} = AMQPTestHelper.wait_and_get_message()
    assert conn_headers["x_astarte_event_type"] == "device_connected_event"
    assert conn_headers["x_astarte_realm"] == realm
    assert conn_headers["x_astarte_device_id"] == encoded_device_id

    assert :uuid.string_to_uuid(conn_headers["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(conn_headers["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.device_connected_trigger_id()

    assert SimpleEvent.decode(conn_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event: {
               :device_connected_event,
               %DeviceConnectedEvent{
                 device_ip_address: "10.0.0.1"
               }
             },
             timestamp: timestamp_ms,
             parent_trigger_id: DatabaseTestHelper.fake_parent_trigger_id(),
             realm: realm,
             simple_trigger_id: DatabaseTestHelper.device_connected_trigger_id()
           }

    device_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("""
      SELECT connected, total_received_msgs, total_received_bytes,
      exchanged_msgs_by_interface, exchanged_bytes_by_interface
      FROM devices WHERE device_id=:device_id;
      """)
      |> DatabaseQuery.put(:device_id, device_id)

    device_row =
      DatabaseQuery.call!(db_client, device_query)
      |> DatabaseResult.head()

    assert device_row == [
             connected: true,
             total_received_msgs: 45000,
             total_received_bytes: 4_500_000,
             exchanged_msgs_by_interface: nil,
             exchanged_bytes_by_interface: nil
           ]

    # Introspection sub-test
    device_introspection_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT introspection FROM devices WHERE device_id=:device_id;")
      |> DatabaseQuery.put(:device_id, device_id)

    ^existing_introspection_map =
      DatabaseQuery.call!(db_client, device_introspection_query)
      |> DatabaseResult.head()
      |> Keyword.get(:introspection)
      |> Enum.into(%{})

    # Install a volatile incoming introspection test trigger
    incoming_introspection_trigger_data =
      %SimpleTriggerContainer{
        simple_trigger: {
          :device_trigger,
          %DeviceTrigger{
            device_id: encoded_device_id,
            device_event_type: :INCOMING_INTROSPECTION
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    incoming_introspection_trigger_target_data =
      %TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> TriggerTargetContainer.encode()

    incoming_introspection_volatile_trigger_parent_id = :crypto.strong_rand_bytes(16)
    incoming_introspection_volatile_trigger_id = :crypto.strong_rand_bytes(16)

    assert DataUpdater.handle_install_volatile_trigger(
             realm,
             encoded_device_id,
             :uuid.string_to_uuid("0a0da77d-85b5-93d9-d4d2-bd26dd18c9af"),
             2,
             incoming_introspection_volatile_trigger_parent_id,
             incoming_introspection_volatile_trigger_id,
             incoming_introspection_trigger_data,
             incoming_introspection_trigger_target_data
           ) == :ok

    DataUpdater.handle_introspection(
      realm,
      encoded_device_id,
      existing_introspection_string,
      gen_tracking_id(),
      make_timestamp("2017-10-09T14:00:32+00:00")
    )

    {incoming_event, incoming_headers, _meta} = AMQPTestHelper.wait_and_get_message()
    assert incoming_headers["x_astarte_event_type"] == "incoming_introspection_event"
    assert incoming_headers["x_astarte_device_id"] == encoded_device_id
    assert incoming_headers["x_astarte_realm"] == realm

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_parent_trigger_id"]) ==
             incoming_introspection_volatile_trigger_parent_id

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_simple_trigger_id"]) ==
             incoming_introspection_volatile_trigger_id

    assert SimpleEvent.decode(incoming_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event: {
               :incoming_introspection_event,
               %IncomingIntrospectionEvent{
                 introspection: existing_introspection_string
               }
             },
             timestamp: timestamp_ms,
             parent_trigger_id: incoming_introspection_volatile_trigger_parent_id,
             realm: realm,
             simple_trigger_id: incoming_introspection_volatile_trigger_id
           }

    # Remove the incoming introspection trigger, don't curse next tests
    assert DataUpdater.handle_delete_volatile_trigger(
             realm,
             encoded_device_id,
             incoming_introspection_volatile_trigger_id
           ) == :ok

    # Install a volatile interface added introspection test trigger
    interface_added_trigger_data =
      %SimpleTriggerContainer{
        simple_trigger: {
          :device_trigger,
          %DeviceTrigger{
            device_id: encoded_device_id,
            device_event_type: :INTERFACE_ADDED,
            interface_name: "*"
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    interface_added_trigger_target_data =
      %TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> TriggerTargetContainer.encode()

    interface_added_volatile_trigger_parent_id = :crypto.strong_rand_bytes(16)
    interface_added_volatile_trigger_id = :crypto.strong_rand_bytes(16)

    assert DataUpdater.handle_install_volatile_trigger(
             realm,
             encoded_device_id,
             :uuid.string_to_uuid("0a0da77d-85b5-93d9-d4d2-bd26dd18c9af"),
             2,
             interface_added_volatile_trigger_parent_id,
             interface_added_volatile_trigger_id,
             interface_added_trigger_data,
             interface_added_trigger_target_data
           ) == :ok

    new_introspection = existing_introspection_string <> ";com.test.YetAnother:1:0"

    DataUpdater.handle_introspection(
      realm,
      encoded_device_id,
      new_introspection,
      gen_tracking_id(),
      make_timestamp("2017-10-09T14:00:32+00:00")
    )

    {incoming_event, incoming_headers, _meta} = AMQPTestHelper.wait_and_get_message()
    assert incoming_headers["x_astarte_event_type"] == "interface_added_event"
    assert incoming_headers["x_astarte_device_id"] == encoded_device_id
    assert incoming_headers["x_astarte_realm"] == realm

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_parent_trigger_id"]) ==
             interface_added_volatile_trigger_parent_id

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_simple_trigger_id"]) ==
             interface_added_volatile_trigger_id

    assert SimpleEvent.decode(incoming_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event: {
               :interface_added_event,
               %InterfaceAddedEvent{
                 interface: "com.test.YetAnother",
                 major_version: 1,
                 minor_version: 0
               }
             },
             timestamp: timestamp_ms,
             parent_trigger_id: interface_added_volatile_trigger_parent_id,
             realm: realm,
             simple_trigger_id: interface_added_volatile_trigger_id
           }

    # Remove the interface added trigger, don't curse next tests
    assert DataUpdater.handle_delete_volatile_trigger(
             realm,
             encoded_device_id,
             interface_added_volatile_trigger_id
           ) == :ok

    # Install a volatile interface minor updated introspection test trigger
    interface_minor_updated_trigger_data =
      %SimpleTriggerContainer{
        simple_trigger: {
          :device_trigger,
          %DeviceTrigger{
            device_id: encoded_device_id,
            device_event_type: :INTERFACE_MINOR_UPDATED,
            interface_name: "com.test.YetAnother",
            interface_major: 1
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    interface_minor_updated_trigger_target_data =
      %TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> TriggerTargetContainer.encode()

    interface_minor_updated_volatile_trigger_parent_id = :crypto.strong_rand_bytes(16)
    interface_minor_updated_volatile_trigger_id = :crypto.strong_rand_bytes(16)

    assert DataUpdater.handle_install_volatile_trigger(
             realm,
             encoded_device_id,
             :uuid.string_to_uuid("0a0da77d-85b5-93d9-d4d2-bd26dd18c9af"),
             2,
             interface_minor_updated_volatile_trigger_parent_id,
             interface_minor_updated_volatile_trigger_id,
             interface_minor_updated_trigger_data,
             interface_minor_updated_trigger_target_data
           ) == :ok

    new_introspection = existing_introspection_string <> ";com.test.YetAnother:1:1"

    DataUpdater.handle_introspection(
      realm,
      encoded_device_id,
      new_introspection,
      gen_tracking_id(),
      make_timestamp("2017-10-09T14:00:32+00:00")
    )

    {incoming_event, incoming_headers, _meta} = AMQPTestHelper.wait_and_get_message()
    assert incoming_headers["x_astarte_event_type"] == "interface_minor_updated_event"
    assert incoming_headers["x_astarte_device_id"] == encoded_device_id
    assert incoming_headers["x_astarte_realm"] == realm

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_parent_trigger_id"]) ==
             interface_minor_updated_volatile_trigger_parent_id

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_simple_trigger_id"]) ==
             interface_minor_updated_volatile_trigger_id

    assert SimpleEvent.decode(incoming_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event: {
               :interface_minor_updated_event,
               %InterfaceMinorUpdatedEvent{
                 interface: "com.test.YetAnother",
                 major_version: 1,
                 old_minor_version: 0,
                 new_minor_version: 1
               }
             },
             timestamp: timestamp_ms,
             parent_trigger_id: interface_minor_updated_volatile_trigger_parent_id,
             realm: realm,
             simple_trigger_id: interface_minor_updated_volatile_trigger_id
           }

    # Remove the interface minor updated trigger, don't curse next tests
    assert DataUpdater.handle_delete_volatile_trigger(
             realm,
             encoded_device_id,
             interface_minor_updated_volatile_trigger_id
           ) == :ok

    # Install a volatile interface removed introspection test trigger
    interface_removed_trigger_data =
      %SimpleTriggerContainer{
        simple_trigger: {
          :device_trigger,
          %DeviceTrigger{
            device_id: encoded_device_id,
            device_event_type: :INTERFACE_REMOVED,
            interface_name: "*"
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    interface_removed_trigger_target_data =
      %TriggerTargetContainer{
        trigger_target: {
          :amqp_trigger_target,
          %AMQPTriggerTarget{
            routing_key: AMQPTestHelper.events_routing_key()
          }
        }
      }
      |> TriggerTargetContainer.encode()

    interface_removed_volatile_trigger_parent_id = :crypto.strong_rand_bytes(16)
    interface_removed_volatile_trigger_id = :crypto.strong_rand_bytes(16)

    assert DataUpdater.handle_install_volatile_trigger(
             realm,
             encoded_device_id,
             :uuid.string_to_uuid("0a0da77d-85b5-93d9-d4d2-bd26dd18c9af"),
             2,
             interface_removed_volatile_trigger_parent_id,
             interface_removed_volatile_trigger_id,
             interface_removed_trigger_data,
             interface_removed_trigger_target_data
           ) == :ok

    DataUpdater.handle_introspection(
      realm,
      encoded_device_id,
      existing_introspection_string,
      gen_tracking_id(),
      make_timestamp("2017-10-09T14:00:32+00:00")
    )

    {incoming_event, incoming_headers, _meta} = AMQPTestHelper.wait_and_get_message()
    assert incoming_headers["x_astarte_event_type"] == "interface_removed_event"
    assert incoming_headers["x_astarte_device_id"] == encoded_device_id
    assert incoming_headers["x_astarte_realm"] == realm

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_parent_trigger_id"]) ==
             interface_removed_volatile_trigger_parent_id

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_simple_trigger_id"]) ==
             interface_removed_volatile_trigger_id

    assert SimpleEvent.decode(incoming_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event: {
               :interface_removed_event,
               %InterfaceRemovedEvent{
                 interface: "com.test.YetAnother",
                 major_version: 1
               }
             },
             timestamp: timestamp_ms,
             parent_trigger_id: interface_removed_volatile_trigger_parent_id,
             realm: realm,
             simple_trigger_id: interface_removed_volatile_trigger_id
           }

    # Remove the interface removed trigger, don't curse next tests
    assert DataUpdater.handle_delete_volatile_trigger(
             realm,
             encoded_device_id,
             interface_removed_volatile_trigger_id
           ) == :ok

    DataUpdater.dump_state(realm, encoded_device_id)

    device_introspection =
      DatabaseQuery.call!(db_client, device_introspection_query)
      |> DatabaseResult.head()
      |> Keyword.get(:introspection)
      |> Enum.into(%{})

    assert existing_introspection_map == device_introspection

    # Install a volatile test trigger
    simple_trigger_data =
      %SimpleTriggerContainer{
        simple_trigger: {
          :data_trigger,
          %DataTrigger{
            interface_name: "com.test.SimpleStreamTest",
            interface_major: 1,
            data_trigger_type: :INCOMING_DATA,
            match_path: "/0/value",
            value_match_operator: :LESS_THAN,
            known_value: Cyanide.encode!(%{v: 100})
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
             :uuid.string_to_uuid("0a0da77d-85b5-93d9-d4d2-bd26dd18c9af"),
             2,
             volatile_trigger_parent_id,
             volatile_trigger_id,
             simple_trigger_data,
             trigger_target_data
           ) == :ok

    # Install a volatile test trigger that won't match, to check that multiple triggers
    # for a single interface/endpoint are correctly loaded
    non_matching_simple_trigger_data =
      %SimpleTriggerContainer{
        simple_trigger: {
          :data_trigger,
          %DataTrigger{
            interface_name: "com.test.SimpleStreamTest",
            interface_major: 1,
            data_trigger_type: :INCOMING_DATA,
            match_path: "/0/value",
            value_match_operator: :GREATER_THAN,
            known_value: Cyanide.encode!(%{v: 1000})
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    non_matching_volatile_trigger_parent_id = :crypto.strong_rand_bytes(16)
    non_matching_volatile_trigger_id = :crypto.strong_rand_bytes(16)

    # Install the non-matching trigger twice to check that this installs 2 trigger_targets
    assert DataUpdater.handle_install_volatile_trigger(
             realm,
             encoded_device_id,
             :uuid.string_to_uuid("0a0da77d-85b5-93d9-d4d2-bd26dd18c9af"),
             2,
             non_matching_volatile_trigger_parent_id,
             non_matching_volatile_trigger_id,
             non_matching_simple_trigger_data,
             trigger_target_data
           ) == :ok

    assert DataUpdater.handle_install_volatile_trigger(
             realm,
             encoded_device_id,
             :uuid.string_to_uuid("0a0da77d-85b5-93d9-d4d2-bd26dd18c9af"),
             2,
             non_matching_volatile_trigger_parent_id,
             non_matching_volatile_trigger_id,
             non_matching_simple_trigger_data,
             trigger_target_data
           ) == :ok

    # Incoming data sub-test
    timestamp_us_x_10 = make_timestamp("2017-10-09T14:10:31+00:00")
    timestamp_ms = div(timestamp_us_x_10, 10_000)

    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.test.LCDMonitor",
      "/weekSchedule/3/start",
      Cyanide.encode!(%{"v" => 1}),
      gen_tracking_id(),
      timestamp_us_x_10
    )

    {incoming_event, incoming_headers, _meta} = AMQPTestHelper.wait_and_get_message()
    assert incoming_headers["x_astarte_event_type"] == "incoming_data_event"
    assert incoming_headers["x_astarte_device_id"] == encoded_device_id
    assert incoming_headers["x_astarte_realm"] == realm

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.less_than_device_incoming_trigger_id()

    assert SimpleEvent.decode(incoming_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event: {
               :incoming_data_event,
               %IncomingDataEvent{
                 bson_value: Cyanide.encode!(%{"v" => 1}),
                 interface: "com.test.LCDMonitor",
                 path: "/weekSchedule/3/start"
               }
             },
             timestamp: timestamp_ms,
             parent_trigger_id: DatabaseTestHelper.fake_parent_trigger_id(),
             realm: realm,
             simple_trigger_id: DatabaseTestHelper.less_than_device_incoming_trigger_id()
           }

    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.test.LCDMonitor",
      "/weekSchedule/4/start",
      Cyanide.encode!(%{"v" => 3}),
      gen_tracking_id(),
      timestamp_us_x_10
    )

    {incoming_event, incoming_headers, _meta} = AMQPTestHelper.wait_and_get_message()
    assert incoming_headers["x_astarte_event_type"] == "incoming_data_event"
    assert incoming_headers["x_astarte_device_id"] == encoded_device_id
    assert incoming_headers["x_astarte_realm"] == realm

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.equal_to_group_incoming_trigger_id()

    assert SimpleEvent.decode(incoming_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event: {
               :incoming_data_event,
               %IncomingDataEvent{
                 bson_value: Cyanide.encode!(%{"v" => 3}),
                 interface: "com.test.LCDMonitor",
                 path: "/weekSchedule/4/start"
               }
             },
             timestamp: timestamp_ms,
             parent_trigger_id: DatabaseTestHelper.fake_parent_trigger_id(),
             realm: realm,
             simple_trigger_id: DatabaseTestHelper.equal_to_group_incoming_trigger_id()
           }

    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.test.LCDMonitor",
      "/time/from",
      Cyanide.encode!(%{"v" => 9000}),
      gen_tracking_id(),
      make_timestamp("2017-10-09T14:10:32+00:00")
    )

    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.test.LCDMonitor",
      "/weekSchedule/9/start",
      Cyanide.encode!(%{"v" => 9}),
      gen_tracking_id(),
      make_timestamp("2017-10-09T14:10:32+00:00")
    )

    # Install a volatile value change applied test trigger
    simple_trigger_data =
      %SimpleTriggerContainer{
        simple_trigger: {
          :data_trigger,
          %DataTrigger{
            interface_name: "com.test.LCDMonitor",
            interface_major: 1,
            data_trigger_type: :VALUE_CHANGE_APPLIED,
            match_path: "/weekSchedule/10/start",
            value_match_operator: :ANY
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

    volatile_changed_trigger_parent_id = :crypto.strong_rand_bytes(16)
    volatile_changed_trigger_id = :crypto.strong_rand_bytes(16)

    assert DataUpdater.handle_install_volatile_trigger(
             realm,
             encoded_device_id,
             :uuid.string_to_uuid("798b93a5-842e-bbad-2e4d-d20306838051"),
             2,
             volatile_changed_trigger_parent_id,
             volatile_changed_trigger_id,
             simple_trigger_data,
             trigger_target_data
           ) == :ok

    bad_trigger_data =
      %SimpleTriggerContainer{
        simple_trigger: {
          :data_trigger,
          %DataTrigger{
            interface_name: "com.missing.Interface",
            interface_major: 1,
            data_trigger_type: :VALUE_CHANGE_APPLIED,
            match_path: "/test",
            value_match_operator: :ANY
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    bad_trigger_parent_id = :crypto.strong_rand_bytes(16)
    bad_trigger_id = :crypto.strong_rand_bytes(16)

    assert DataUpdater.handle_install_volatile_trigger(
             realm,
             encoded_device_id,
             :uuid.string_to_uuid("badb93a5-842e-bbad-2e4d-d20306838051"),
             2,
             bad_trigger_parent_id,
             bad_trigger_id,
             bad_trigger_data,
             trigger_target_data
           ) == {:error, :interface_not_found}

    bad_path_trigger_data =
      %SimpleTriggerContainer{
        simple_trigger: {
          :data_trigger,
          %DataTrigger{
            interface_name: "com.test.LCDMonitor",
            interface_major: 1,
            data_trigger_type: :VALUE_CHANGE_APPLIED,
            match_path: "/weekSchedule/10",
            value_match_operator: :ANY
          }
        }
      }
      |> SimpleTriggerContainer.encode()

    bad_path_trigger_parent_id = :crypto.strong_rand_bytes(16)
    bad_path_trigger_id = :crypto.strong_rand_bytes(16)

    assert DataUpdater.handle_install_volatile_trigger(
             realm,
             encoded_device_id,
             :uuid.string_to_uuid("798b93a5-842e-bbad-2e4d-d20306838051"),
             2,
             bad_path_trigger_parent_id,
             bad_path_trigger_id,
             bad_path_trigger_data,
             trigger_target_data
           ) == {:error, :invalid_match_path}

    timestamp_us_x_10 = make_timestamp("2017-10-09T14:10:32+00:00")
    timestamp_ms = div(timestamp_us_x_10, 10_000)

    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.test.LCDMonitor",
      "/weekSchedule/10/start",
      Cyanide.encode!(%{"v" => 10}),
      gen_tracking_id(),
      timestamp_us_x_10
    )

    {incoming_event, incoming_headers, _meta} = AMQPTestHelper.wait_and_get_message()
    assert incoming_headers["x_astarte_event_type"] == "incoming_data_event"
    assert incoming_headers["x_astarte_device_id"] == encoded_device_id
    assert incoming_headers["x_astarte_realm"] == realm

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.greater_than_incoming_trigger_id()

    assert SimpleEvent.decode(incoming_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event: {
               :incoming_data_event,
               %IncomingDataEvent{
                 bson_value: Cyanide.encode!(%{"v" => 10}),
                 interface: "com.test.LCDMonitor",
                 path: "/weekSchedule/10/start"
               }
             },
             timestamp: timestamp_ms,
             parent_trigger_id: DatabaseTestHelper.fake_parent_trigger_id(),
             realm: realm,
             simple_trigger_id: DatabaseTestHelper.greater_than_incoming_trigger_id()
           }

    {incoming_event, incoming_headers, _meta} = AMQPTestHelper.wait_and_get_message()
    assert incoming_headers["x_astarte_event_type"] == "value_change_applied_event"
    assert incoming_headers["x_astarte_device_id"] == encoded_device_id
    assert incoming_headers["x_astarte_realm"] == realm

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_parent_trigger_id"]) ==
             volatile_changed_trigger_parent_id

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_simple_trigger_id"]) ==
             volatile_changed_trigger_id

    assert SimpleEvent.decode(incoming_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event: {
               :value_change_applied_event,
               %ValueChangeAppliedEvent{
                 old_bson_value: Cyanide.encode!(%{"v" => 42}),
                 new_bson_value: Cyanide.encode!(%{"v" => 10}),
                 interface: "com.test.LCDMonitor",
                 path: "/weekSchedule/10/start"
               }
             },
             timestamp: timestamp_ms,
             parent_trigger_id: volatile_changed_trigger_parent_id,
             realm: realm,
             simple_trigger_id: volatile_changed_trigger_id
           }

    timestamp_us_x_10 = make_timestamp("2017-10-09T14:15:32+00:00")
    timestamp_ms = div(timestamp_us_x_10, 10_000)

    # This should trigger matching_simple_trigger
    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.test.SimpleStreamTest",
      "/0/value",
      Cyanide.encode!(%{"v" => 5}),
      gen_tracking_id(),
      timestamp_us_x_10
    )

    state = DataUpdater.dump_state(realm, encoded_device_id)

    {incoming_volatile_event, incoming_volatile_headers, _meta} =
      AMQPTestHelper.wait_and_get_message()

    assert incoming_volatile_headers["x_astarte_event_type"] == "incoming_data_event"
    assert incoming_volatile_headers["x_astarte_device_id"] == encoded_device_id
    assert incoming_volatile_headers["x_astarte_realm"] == realm

    assert :uuid.string_to_uuid(incoming_volatile_headers["x_astarte_parent_trigger_id"]) ==
             volatile_trigger_parent_id

    assert :uuid.string_to_uuid(incoming_volatile_headers["x_astarte_simple_trigger_id"]) ==
             volatile_trigger_id

    assert SimpleEvent.decode(incoming_volatile_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event:
               {:incoming_data_event,
                %IncomingDataEvent{
                  bson_value: Cyanide.encode!(%{"v" => 5}),
                  interface: "com.test.SimpleStreamTest",
                  path: "/0/value"
                }},
             timestamp: timestamp_ms,
             parent_trigger_id: volatile_trigger_parent_id,
             realm: realm,
             simple_trigger_id: volatile_trigger_id
           }

    # We check that all 3 on_incoming_data triggers were correctly installed
    interface_id = CQLUtils.interface_id("com.test.SimpleStreamTest", 1)
    endpoint_id = retrieve_endpoint_id(db_client, "com.test.SimpleStreamTest", 1, "/0/value")
    trigger_key = {:on_incoming_data, interface_id, endpoint_id}
    incoming_data_0_value_triggers = Map.get(state.data_triggers, trigger_key)

    # The length is 2 since greater-then triggers are merged into one because they are congruent
    assert length(incoming_data_0_value_triggers) == 2
    # Extract greater-than trigger
    assert [gt_trigger] =
             Enum.filter(incoming_data_0_value_triggers, fn data_trigger ->
               data_trigger.value_match_operator == :GREATER_THAN
             end)

    # It should have 2 targets
    assert length(gt_trigger.trigger_targets) == 2

    endpoint_id = retrieve_endpoint_id(db_client, "com.test.LCDMonitor", 1, "/time/from")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT longinteger_value FROM individual_properties WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.LCDMonitor", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/time/from")

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == [longinteger_value: 9000]

    endpoint_id = retrieve_endpoint_id(db_client, "com.test.SimpleStreamTest", 1, "/0/value")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT integer_value FROM individual_datastreams WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path AND value_timestamp>=:value_timestamp"
      )
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.SimpleStreamTest", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/0/value")
      |> DatabaseQuery.put(:value_timestamp, 1_507_557_632_000)

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == [integer_value: 5]

    assert DataUpdater.handle_delete_volatile_trigger(
             realm,
             encoded_device_id,
             volatile_trigger_id
           ) == :ok

    timestamp_us_x_10 = make_timestamp("2017-10-09T14:15:32+00:00")
    timestamp_ms = div(timestamp_us_x_10, 10_000)

    # Introspection change subtest
    DataUpdater.handle_introspection(
      realm,
      encoded_device_id,
      "com.test.LCDMonitor:1:0;com.example.TestObject:1:5;com.test.SimpleStreamTest:1:0",
      gen_tracking_id(),
      timestamp_us_x_10
    )

    # Incoming object aggregation subtest
    payload0 = Cyanide.encode!(%{"value" => 1.9, "string" => "Astarteです"})

    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.example.TestObject",
      "/",
      payload0,
      gen_tracking_id(),
      make_timestamp("2017-10-26T08:48:49+00:00")
    )

    payload1 = Cyanide.encode!(%{"string" => "Hello World');"})

    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.example.TestObject",
      "/",
      payload1,
      gen_tracking_id(),
      make_timestamp("2017-10-26T08:48:50+00:00")
    )

    payload2 = Cyanide.encode!(%{"v" => %{"value" => 0}})

    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.example.TestObject",
      "/",
      payload2,
      gen_tracking_id(),
      make_timestamp("2017-10-26T08:48:51+00:00")
    )

    # we expect only /string to be updated here, we need this to check against accidental NULL insertions, that are bad for tombstones on cassandra.
    payload3 = Cyanide.encode!(%{"string" => "zzz"})

    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.example.TestObject",
      "/",
      payload3,
      gen_tracking_id(),
      make_timestamp("2017-09-30T07:13:00+00:00")
    )

    payload4 = Cyanide.encode!(%{})

    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.example.TestObject",
      "/",
      payload4,
      gen_tracking_id(),
      make_timestamp("2017-10-30T07:13:00+00:00")
    )

    DataUpdater.dump_state(realm, encoded_device_id)

    objects_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT * FROM com_example_testobject_v1 WHERE device_id=:device_id AND path='/'"
      )
      |> DatabaseQuery.put(:device_id, device_id)

    objects =
      DatabaseQuery.call!(db_client, objects_query)
      |> Enum.to_list()

    assert objects == [
             [
               device_id: device_id,
               path: "/",
               reception_timestamp: 1_506_755_400_000,
               reception_timestamp_submillis: 0,
               v_string: "aaa",
               v_value: 1.1
             ],
             [
               device_id: device_id,
               path: "/",
               reception_timestamp: 1_506_755_520_000,
               reception_timestamp_submillis: 0,
               v_string: "bbb",
               v_value: 2.2
             ],
             [
               device_id: device_id,
               path: "/",
               reception_timestamp: 1_506_755_580_000,
               reception_timestamp_submillis: 0,
               v_string: "zzz",
               v_value: 3.3
             ],
             [
               device_id: device_id,
               path: "/",
               reception_timestamp: 1_509_007_729_000,
               reception_timestamp_submillis: 0,
               v_string: "Astarteです",
               v_value: 1.9
             ],
             [
               device_id: device_id,
               path: "/",
               reception_timestamp: 1_509_007_730_000,
               reception_timestamp_submillis: 0,
               v_string: "Hello World');",
               v_value: nil
             ],
             [
               device_id: device_id,
               path: "/",
               reception_timestamp: 1_509_007_731_000,
               reception_timestamp_submillis: 0,
               v_string: nil,
               v_value: 0.0
             ],
             [
               device_id: device_id,
               path: "/",
               reception_timestamp: 1_509_347_580_000,
               reception_timestamp_submillis: 0,
               v_string: nil,
               v_value: nil
             ]
           ]

    # Test /producer/properties control message
    data =
      <<0, 0, 0, 98>> <>
        :zlib.compress("com.test.LCDMonitor/time/to;com.test.LCDMonitor/weekSchedule/10/start")

    timestamp_us_x_10 = make_timestamp("2017-10-09T14:00:32+00:00")
    timestamp_ms = div(timestamp_us_x_10, 10_000)

    DataUpdater.handle_control(
      realm,
      encoded_device_id,
      "/producer/properties",
      data,
      gen_tracking_id(),
      timestamp_us_x_10
    )

    DataUpdater.dump_state(realm, encoded_device_id)
    {remove_event, remove_headers, _meta} = AMQPTestHelper.wait_and_get_message()
    assert remove_headers["x_astarte_event_type"] == "path_removed_event"
    assert remove_headers["x_astarte_device_id"] == encoded_device_id
    assert remove_headers["x_astarte_realm"] == "autotestrealm"

    assert :uuid.string_to_uuid(remove_headers["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(remove_headers["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.path_removed_trigger_id()

    assert SimpleEvent.decode(remove_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event:
               {:path_removed_event,
                %PathRemovedEvent{interface: "com.test.LCDMonitor", path: "/time/from"}},
             timestamp: timestamp_ms,
             parent_trigger_id: DatabaseTestHelper.fake_parent_trigger_id(),
             realm: "autotestrealm",
             simple_trigger_id: DatabaseTestHelper.path_removed_trigger_id()
           }

    endpoint_id = retrieve_endpoint_id(db_client, "com.test.LCDMonitor", 1, "/time/from")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT longinteger_value FROM individual_properties WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.LCDMonitor", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/time/from")

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == :empty_dataset

    endpoint_id =
      retrieve_endpoint_id(db_client, "com.test.LCDMonitor", 1, "/weekSchedule/9/start")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT longinteger_value FROM individual_properties WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.LCDMonitor", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/weekSchedule/9/start")

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == :empty_dataset

    endpoint_id =
      retrieve_endpoint_id(db_client, "com.test.LCDMonitor", 1, "/weekSchedule/10/start")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT longinteger_value FROM individual_properties WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.LCDMonitor", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/weekSchedule/10/start")

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == [longinteger_value: 10]

    endpoint_id = retrieve_endpoint_id(db_client, "com.test.SimpleStreamTest", 1, "/0/value")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT integer_value FROM individual_datastreams WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path AND value_timestamp>=:value_timestamp"
      )
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.SimpleStreamTest", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/0/value")
      |> DatabaseQuery.put(:value_timestamp, 1_507_557_632_000)

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == [integer_value: 5]

    # Unset subtest

    # Delete it otherwise it gets raised
    assert DataUpdater.handle_delete_volatile_trigger(
             realm,
             encoded_device_id,
             volatile_changed_trigger_id
           ) == :ok

    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "com.test.LCDMonitor",
      "/weekSchedule/10/start",
      <<>>,
      gen_tracking_id(),
      make_timestamp("2017-10-09T15:10:32+00:00")
    )

    DataUpdater.dump_state(realm, encoded_device_id)

    endpoint_id =
      retrieve_endpoint_id(db_client, "com.test.LCDMonitor", 1, "/weekSchedule/10/start")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT longinteger_value FROM individual_properties WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.LCDMonitor", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/weekSchedule/10/start")

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == :empty_dataset

    # Device disconnection sub-test
    DataUpdater.handle_disconnection(
      realm,
      encoded_device_id,
      gen_tracking_id(),
      make_timestamp("2017-10-09T14:30:45+00:00")
    )

    DataUpdater.dump_state(realm, encoded_device_id)

    device_row =
      DatabaseQuery.call!(db_client, device_query)
      |> DatabaseResult.head()

    assert device_row == [
             connected: false,
             total_received_msgs: 45018,
             total_received_bytes: 4_501_003,
             exchanged_msgs_by_interface: [
               {["com.example.TestObject", 1], 5},
               {["com.test.LCDMonitor", 1], 6},
               {["com.test.SimpleStreamTest", 1], 1}
             ],
             exchanged_bytes_by_interface: [
               {["com.example.TestObject", 1], 243},
               {["com.test.LCDMonitor", 1], 291},
               {["com.test.SimpleStreamTest", 1], 45}
             ]
           ]

    assert AMQPTestHelper.awaiting_messages_count() == 0
  end

  test "empty introspection is updated correctly" do
    AMQPTestHelper.clean_queue()

    realm = "autotestrealm"

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)
    new_introspection_map = %{"com.test.LCDMonitor" => 1, "com.test.SimpleStreamTest" => 1}
    new_introspection_string = "com.test.LCDMonitor:1:0;com.test.SimpleStreamTest:1:0"

    DatabaseTestHelper.insert_device(device_id, groups: ["group2"])

    {:ok, db_client} = Database.connect(realm: realm)

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

    {conn_event, conn_headers, _metadata} = AMQPTestHelper.wait_and_get_message()
    assert conn_headers["x_astarte_event_type"] == "device_connected_event"
    assert conn_headers["x_astarte_realm"] == realm
    assert conn_headers["x_astarte_device_id"] == encoded_device_id

    assert :uuid.string_to_uuid(conn_headers["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(conn_headers["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.group2_device_connected_trigger_id()

    assert SimpleEvent.decode(conn_event) == %SimpleEvent{
             device_id: encoded_device_id,
             event: {
               :device_connected_event,
               %DeviceConnectedEvent{
                 device_ip_address: "10.0.0.1"
               }
             },
             timestamp: timestamp_ms,
             parent_trigger_id: DatabaseTestHelper.fake_parent_trigger_id(),
             realm: realm,
             simple_trigger_id: DatabaseTestHelper.group2_device_connected_trigger_id()
           }

    device_introspection_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT introspection FROM devices WHERE device_id=:device_id;")
      |> DatabaseQuery.put(:device_id, device_id)

    old_device_introspection =
      DatabaseQuery.call!(db_client, device_introspection_query)
      |> DatabaseResult.head()
      |> Keyword.get(:introspection)

    assert old_device_introspection == nil

    timestamp_us_x_10 = make_timestamp("2017-10-09T14:00:32+00:00")
    timestamp_ms = div(timestamp_us_x_10, 10_000)

    DataUpdater.handle_introspection(
      realm,
      encoded_device_id,
      new_introspection_string,
      gen_tracking_id(),
      timestamp_us_x_10
    )

    DataUpdater.dump_state(realm, encoded_device_id)

    new_device_introspection =
      DatabaseQuery.call!(db_client, device_introspection_query)
      |> DatabaseResult.head()
      |> Keyword.get(:introspection)
      |> Enum.into(%{})

    assert new_device_introspection == new_introspection_map

    assert AMQPTestHelper.awaiting_messages_count() == 0
  end

  test "test introspection with interface update" do
    AMQPTestHelper.clean_queue()

    realm = "autotestrealm"

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    DatabaseTestHelper.insert_device(device_id)
    {:ok, db_client} = Database.connect(realm: realm)

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
    assert DatabaseTestHelper.fetch_old_introspection(db_client, device_id) == {:ok, %{}}

    new_introspection_string = "com.test.LCDMonitor:2:0;com.test.SimpleStreamTest:1:0"

    DataUpdater.handle_introspection(
      realm,
      encoded_device_id,
      new_introspection_string,
      gen_tracking_id(),
      make_timestamp("2017-10-09T15:00:32+00:00")
    )

    DataUpdater.dump_state(realm, encoded_device_id)
    DatabaseTestHelper.fetch_old_introspection(db_client, device_id)

    assert DatabaseTestHelper.fetch_old_introspection(db_client, device_id) ==
             {:ok,
              %{
                ["com.test.LCDMonitor", 1] => 0
              }}

    new_introspection_string = "com.test.LCDMonitor:2:0"

    DataUpdater.handle_introspection(
      realm,
      encoded_device_id,
      new_introspection_string,
      gen_tracking_id(),
      make_timestamp("2017-10-09T16:00:32+00:00")
    )

    DataUpdater.dump_state(realm, encoded_device_id)

    assert DatabaseTestHelper.fetch_old_introspection(db_client, device_id) ==
             {:ok,
              %{
                ["com.test.LCDMonitor", 1] => 0,
                ["com.test.SimpleStreamTest", 1] => 0
              }}
  end

  test "fails to install volatile trigger on missing device" do
    AMQPTestHelper.clean_queue()

    realm = "autotestrealm"

    {:ok, db_client} = Database.connect(realm: realm)

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
            routing_key: AMQPTestHelper.events_routing_key()
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

  test "fails to delete volatile trigger on missing device" do
    AMQPTestHelper.clean_queue()
    realm = "autotestrealm"
    {:ok, db_client} = Database.connect(realm: realm)
    volatile_trigger_id = :crypto.strong_rand_bytes(16)

    fail_encoded_device_id = "f0VMRgIBAQBBBBBBBBBBBB"
    {:ok, fail_device_id} = Device.decode_device_id(fail_encoded_device_id)

    assert DataUpdater.handle_delete_volatile_trigger(
             realm,
             fail_encoded_device_id,
             volatile_trigger_id
           ) == {:error, :device_does_not_exist}
  end

  test "heartbeat message of type internal is correctly handled" do
    alias Astarte.DataUpdaterPlant.DataUpdater.State

    AMQPTestHelper.clean_queue()

    realm = "autotestrealm"

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    DatabaseTestHelper.insert_device(device_id)

    {:ok, db_client} = Database.connect(realm: realm)

    timestamp_us_x_10 = make_timestamp("2017-12-09T14:00:32+00:00")
    timestamp_ms = div(timestamp_us_x_10, 10_000)

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
  test "heartbeat message of type heartbeat is correctly handled" do
    alias Astarte.DataUpdaterPlant.DataUpdater.State

    AMQPTestHelper.clean_queue()

    realm = "autotestrealm"

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    DatabaseTestHelper.insert_device(device_id)

    {:ok, db_client} = Database.connect(realm: realm)

    timestamp_us_x_10 = make_timestamp("2017-12-09T14:00:32+00:00")
    timestamp_ms = div(timestamp_us_x_10, 10_000)

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

  test "device deletion is acked and related DataUpdater process stops" do
    AMQPTestHelper.clean_queue()

    realm = "autotestrealm"

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    # Register the device with some fake data
    total_received_messages = 42
    total_received_bytes = 4242

    insert_opts = [
      total_received_msgs: total_received_messages,
      total_received_bytes: total_received_bytes
    ]

    DatabaseTestHelper.insert_device(device_id, insert_opts)

    # Set device deletion to in progress
    deletion_in_progress_statement = """
    INSERT INTO #{realm}.deletion_in_progress (device_id)
    VALUES (:device_id)
    """

    Xandra.Cluster.run(:xandra, fn conn ->
      prepared = Xandra.prepare!(conn, deletion_in_progress_statement)

      %Xandra.Void{} =
        Xandra.execute!(conn, prepared, %{"device_id" => device_id}, uuid_format: :binary)
    end)

    # We expect that sooner or later the device will be disconnected
    MockRPCClient
    |> expect(:rpc_call, fn serialized_call, @vmq_plugin_destination ->
      assert %Call{call: {:delete, %Delete{} = delete_call}} = Call.decode(serialized_call)

      assert %Delete{
               realm_name: realm,
               device_id: encoded_device_id
             } = delete_call

      {:ok, @encoded_generic_ok_reply}
    end)

    timestamp_us_x_10 = make_timestamp("2017-10-09T15:00:32+00:00")
    timestamp_ms = div(timestamp_us_x_10, 10_000)

    DataUpdater.start_device_deletion(realm, encoded_device_id, timestamp_ms)

    # Check DUP start ack in deleted_devices table
    dup_start_ack_statement = """
    SELECT dup_start_ack
    FROM #{realm}.deletion_in_progress
    WHERE device_id = :device_id
    """

    dup_start_ack_result =
      Xandra.Cluster.run(:xandra, fn conn ->
        prepared = Xandra.prepare!(conn, dup_start_ack_statement)

        %Xandra.Page{} =
          page =
          Xandra.execute!(conn, prepared, %{"device_id" => device_id}, uuid_format: :binary)

        Enum.to_list(page)
      end)

    assert [%{"dup_start_ack" => true}] = dup_start_ack_result

    # Check that no data is being handled
    DataUpdater.handle_data(
      realm,
      encoded_device_id,
      "this.interface.does.not.Exist",
      "/don/t/care",
      :dontcare,
      gen_tracking_id(),
      make_timestamp("2017-10-09T14:30:15+00:00")
    )

    received_data_statement = """
    SELECT total_received_msgs, total_received_bytes
    FROM #{realm}.devices WHERE device_id=:device_id;
    """

    received_data_result =
      Xandra.Cluster.run(:xandra, fn conn ->
        prepared = Xandra.prepare!(conn, received_data_statement)

        %Xandra.Page{} =
          page =
          Xandra.execute!(conn, prepared, %{"device_id" => device_id}, uuid_format: :binary)

        Enum.to_list(page)
      end)

    assert [
             %{
               "total_received_msgs" => ^total_received_messages,
               "total_received_bytes" => ^total_received_bytes
             }
           ] = received_data_result

    # Now process the device's last message
    DataUpdater.handle_internal(
      realm,
      encoded_device_id,
      "/f",
      :dontcare,
      gen_tracking_id(),
      timestamp_us_x_10
    )

    # Let the process handle device's last message
    Process.sleep(100)

    # Check DUP end ack in deleted_devices table
    dup_end_ack_statement = """
    SELECT dup_end_ack
    FROM #{realm}.deletion_in_progress
    WHERE device_id = :device_id
    """

    dup_end_ack_result =
      Xandra.Cluster.run(:xandra, fn conn ->
        prepared = Xandra.prepare!(conn, dup_end_ack_statement)

        %Xandra.Page{} =
          page =
          Xandra.execute!(conn, prepared, %{"device_id" => device_id}, uuid_format: :binary)

        Enum.to_list(page)
      end)

    assert [%{"dup_end_ack" => true}] = dup_end_ack_result

    # Finally, check that the related DataUpdater process exists no more
    assert [] = Registry.lookup(Registry.DataUpdater, {realm, device_id})
  end

  defp retrieve_endpoint_id(client, interface_name, interface_major, path) do
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT * FROM interfaces WHERE name = :name AND major_version = :major_version;"
      )
      |> DatabaseQuery.put(:name, interface_name)
      |> DatabaseQuery.put(:major_version, interface_major)

    interface_row =
      DatabaseQuery.call!(client, query)
      |> Enum.take(1)
      |> hd

    automaton =
      {:erlang.binary_to_term(interface_row[:automaton_transitions]),
       :erlang.binary_to_term(interface_row[:automaton_accepting_states])}

    {:ok, endpoint_id} = Astarte.Core.Mapping.EndpointsAutomaton.resolve_path(path, automaton)

    endpoint_id
  end

  defp make_timestamp(timestamp_string) do
    {:ok, date_time, _} = DateTime.from_iso8601(timestamp_string)

    DateTime.to_unix(date_time, :millisecond) * 10000
  end

  defp gen_tracking_id() do
    message_id = :erlang.unique_integer([:monotonic]) |> Integer.to_string()
    delivery_tag = {:injected_msg, make_ref()}
    {message_id, delivery_tag}
  end
end
