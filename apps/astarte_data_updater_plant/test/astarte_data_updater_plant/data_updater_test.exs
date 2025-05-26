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
  use ExUnit.Case, async: true
  import Mox

  import Ecto.Query

  alias Astarte.Core.Device
  alias Astarte.Core.Triggers.SimpleEvents.DeviceConnectedEvent
  alias Astarte.Core.Triggers.SimpleEvents.DeviceDisconnectedEvent
  alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent
  alias Astarte.Core.Triggers.SimpleEvents.PathRemovedEvent
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Triggers.SimpleEvents.ValueChangeAppliedEvent
  alias Astarte.Core.Triggers.SimpleEvents.IncomingIntrospectionEvent
  alias Astarte.Core.Triggers.SimpleEvents.InterfaceAddedEvent
  alias Astarte.Core.Triggers.SimpleEvents.InterfaceRemovedEvent
  alias Astarte.Core.Triggers.SimpleEvents.InterfaceMinorUpdatedEvent
  alias Astarte.Core.Triggers.SimpleEvents.InterfaceVersion
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.DataAccess.Devices.Device, as: DeviceSchema
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Realms.IndividualDatastream
  alias Astarte.DataAccess.Realms.IndividualProperty
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.DataUpdaterPlant.AMQPTestHelper
  alias Astarte.DataUpdaterPlant.DatabaseTestHelper
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.Repo
  alias Astarte.Core.CQLUtils

  setup :verify_on_exit!

  setup_all do
    realm = "autotestrealm#{System.unique_integer([:positive])}"
    {:ok, _keyspace_name} = DatabaseTestHelper.create_test_keyspace(realm)

    on_exit(fn ->
      DatabaseTestHelper.destroy_local_test_keyspace(realm)
    end)

    {:ok, _pid} = AMQPTestHelper.start_link()
    %{realm: realm}
  end

  test "simple flow", %{realm: realm} do
    AMQPTestHelper.clean_queue()

    keyspace_name = Realm.keyspace_name(realm)
    encoded_device_id = "f0VMRgIBAQAAAAAAAAAAAA"
    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    received_msgs = 45000
    received_bytes = 4_500_000
    existing_introspection_map = %{"com.test.LCDMonitor" => 1, "com.test.SimpleStreamTest" => 1}
    existing_introspection_string = "com.test.LCDMonitor:1:0;com.test.SimpleStreamTest:1:0"

    existing_introspection_proto_map = %{
      "com.test.LCDMonitor" => %InterfaceVersion{major: 1, minor: 0},
      "com.test.SimpleStreamTest" => %InterfaceVersion{major: 1, minor: 0}
    }

    insert_opts = [
      introspection: existing_introspection_map,
      total_received_msgs: received_msgs,
      total_received_bytes: received_bytes,
      groups: ["group1"]
    ]

    DatabaseTestHelper.insert_device(realm, device_id, insert_opts)

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
      from d in DeviceSchema,
        prefix: ^keyspace_name,
        where: d.device_id == ^device_id,
        select: %{
          connected: d.connected,
          total_received_msgs: d.total_received_msgs,
          total_received_bytes: d.total_received_bytes,
          exchanged_msgs_by_interface: d.exchanged_msgs_by_interface,
          exchanged_bytes_by_interface: d.exchanged_bytes_by_interface
        }

    device_row = Repo.one(device_query)

    assert device_row == %{
             connected: true,
             total_received_msgs: 45000,
             total_received_bytes: 4_500_000,
             exchanged_msgs_by_interface: %{},
             exchanged_bytes_by_interface: %{}
           }

    # Introspection sub-test
    device_introspection_query =
      from d in DeviceSchema,
        prefix: ^keyspace_name,
        where: d.device_id == ^device_id,
        select: d.introspection

    ^existing_introspection_map = Repo.one(device_introspection_query)

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
                 introspection_map: existing_introspection_proto_map
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

    device_introspection = Repo.one(device_introspection_query)

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
    endpoint_id = retrieve_endpoint_id(realm, "com.test.SimpleStreamTest", 1, "/0/value")
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

    endpoint_id = retrieve_endpoint_id(realm, "com.test.LCDMonitor", 1, "/time/from")

    value_query =
      from ip in IndividualProperty,
        prefix: ^keyspace_name,
        where:
          ip.device_id == ^device_id and
            ip.interface_id == ^CQLUtils.interface_id("com.test.LCDMonitor", 1) and
            ip.endpoint_id == ^endpoint_id and
            ip.path == "/time/from",
        select: ip.longinteger_value

    value = Repo.one(value_query)

    assert value == 9000

    endpoint_id = retrieve_endpoint_id(realm, "com.test.SimpleStreamTest", 1, "/0/value")

    timestamp_ms = DateTime.from_unix!(1_507_557_632_000, :millisecond)

    value_query =
      from id in IndividualDatastream,
        prefix: ^keyspace_name,
        where:
          id.device_id == ^device_id and
            id.interface_id == ^CQLUtils.interface_id("com.test.SimpleStreamTest", 1) and
            id.endpoint_id == ^endpoint_id and
            id.path == "/0/value" and
            id.value_timestamp >= ^timestamp_ms,
        select: id.integer_value

    value = Repo.one(value_query)

    assert value == 5

    assert DataUpdater.handle_delete_volatile_trigger(
             realm,
             encoded_device_id,
             volatile_trigger_id
           ) == :ok

    timestamp_us_x_10 = make_timestamp("2017-10-09T14:15:32+00:00")

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

    payload2 = Cyanide.encode!(%{"v" => %{"value" => 0.0}})

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
      from o in "com_example_testobject_v1",
        prefix: ^realm,
        where: o.device_id == ^device_id and o.path == "/",
        select: [
          device_id: o.device_id,
          path: o.path,
          reception_timestamp: fragment("toUnixTimestamp(?)", o.reception_timestamp),
          reception_timestamp_submillis: o.reception_timestamp_submillis,
          v_string: o.v_string,
          v_value: o.v_value
        ]

    objects = Repo.all(objects_query)

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
    assert remove_headers["x_astarte_realm"] == realm

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
             realm: realm,
             simple_trigger_id: DatabaseTestHelper.path_removed_trigger_id()
           }

    endpoint_id = retrieve_endpoint_id(realm, "com.test.LCDMonitor", 1, "/time/from")

    value_query =
      from ip in IndividualProperty,
        prefix: ^keyspace_name,
        where:
          ip.device_id == ^device_id and
            ip.interface_id == ^CQLUtils.interface_id("com.test.LCDMonitor", 1) and
            ip.endpoint_id == ^endpoint_id and
            ip.path == "/time/from",
        select: ip.longinteger_value

    value = Repo.one(value_query)

    assert value == nil

    endpoint_id =
      retrieve_endpoint_id(realm, "com.test.LCDMonitor", 1, "/weekSchedule/9/start")

    value_query =
      from ip in IndividualProperty,
        prefix: ^keyspace_name,
        where:
          ip.device_id == ^device_id and
            ip.interface_id == ^CQLUtils.interface_id("com.test.LCDMonitor", 1) and
            ip.endpoint_id == ^endpoint_id and
            ip.path == "/weekSchedule/9/start",
        select: ip.longinteger_value

    value = Repo.one(value_query)

    assert value == nil

    endpoint_id =
      retrieve_endpoint_id(realm, "com.test.LCDMonitor", 1, "/weekSchedule/10/start")

    value_query =
      from ip in IndividualProperty,
        prefix: ^keyspace_name,
        where:
          ip.device_id == ^device_id and
            ip.interface_id == ^CQLUtils.interface_id("com.test.LCDMonitor", 1) and
            ip.endpoint_id == ^endpoint_id and
            ip.path == "/weekSchedule/10/start",
        select: ip.longinteger_value

    value = Repo.one(value_query)

    assert value == 10

    endpoint_id = retrieve_endpoint_id(realm, "com.test.SimpleStreamTest", 1, "/0/value")

    timestamp_ms = DateTime.from_unix!(1_507_557_632_000, :millisecond)

    value_query =
      from id in IndividualDatastream,
        prefix: ^keyspace_name,
        where:
          id.device_id == ^device_id and
            id.interface_id == ^CQLUtils.interface_id("com.test.SimpleStreamTest", 1) and
            id.endpoint_id == ^endpoint_id and
            id.path == "/0/value" and
            id.value_timestamp >= ^timestamp_ms,
        select: id.integer_value

    value = Repo.one(value_query)

    assert value == 5

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
      retrieve_endpoint_id(realm, "com.test.LCDMonitor", 1, "/weekSchedule/10/start")

    value_query =
      from ip in IndividualProperty,
        prefix: ^keyspace_name,
        where:
          ip.device_id == ^device_id and
            ip.interface_id == ^CQLUtils.interface_id("com.test.LCDMonitor", 1) and
            ip.endpoint_id == ^endpoint_id and
            ip.path == "/weekSchedule/10/start",
        select: ip.longinteger_value

    value = Repo.one(value_query)

    assert value == nil

    # Device disconnection sub-test
    DataUpdater.handle_disconnection(
      realm,
      encoded_device_id,
      gen_tracking_id(),
      make_timestamp("2017-10-09T14:30:45+00:00")
    )

    DataUpdater.dump_state(realm, encoded_device_id)

    device_row = Repo.one(device_query)

    assert device_row == %{
             connected: false,
             total_received_msgs: 45018,
             total_received_bytes: 4_501_007,
             exchanged_msgs_by_interface: %{
               {"com.example.TestObject", 1} => 5,
               {"com.test.LCDMonitor", 1} => 6,
               {"com.test.SimpleStreamTest", 1} => 1
             },
             exchanged_bytes_by_interface: %{
               {"com.example.TestObject", 1} => 247,
               {"com.test.LCDMonitor", 1} => 291,
               {"com.test.SimpleStreamTest", 1} => 45
             }
           }

    assert AMQPTestHelper.awaiting_messages_count() == 0
  end

  test "empty introspection is updated correctly", %{realm: realm} do
    AMQPTestHelper.clean_queue()

    keyspace_name = Realm.keyspace_name(realm)

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)
    new_introspection_map = %{"com.test.LCDMonitor" => 1, "com.test.SimpleStreamTest" => 1}
    new_introspection_string = "com.test.LCDMonitor:1:0;com.test.SimpleStreamTest:1:0"

    DatabaseTestHelper.insert_device(realm, device_id, groups: ["group2"])

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

    assert AMQPTestHelper.awaiting_messages_count() == 0
  end

  test "test introspection with interface update", %{realm: realm} do
    AMQPTestHelper.clean_queue()

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    DatabaseTestHelper.insert_device(realm, device_id)

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

  test "fails to install volatile trigger on missing device", %{realm: realm} do
    AMQPTestHelper.clean_queue()

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

  test "fails to delete volatile trigger on missing device", %{realm: realm} do
    AMQPTestHelper.clean_queue()

    volatile_trigger_id = :crypto.strong_rand_bytes(16)

    fail_encoded_device_id = "f0VMRgIBAQBBBBBBBBBBBB"
    {:ok, _fail_device_id} = Device.decode_device_id(fail_encoded_device_id)

    assert DataUpdater.handle_delete_volatile_trigger(
             realm,
             fail_encoded_device_id,
             volatile_trigger_id
           ) == {:error, :device_does_not_exist}
  end

  test "heartbeat message of type internal is correctly handled", %{realm: realm} do
    alias Astarte.DataUpdaterPlant.DataUpdater.State

    AMQPTestHelper.clean_queue()

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    DatabaseTestHelper.insert_device(realm, device_id)

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
  test "heartbeat message of type heartbeat is correctly handled", %{realm: realm} do
    alias Astarte.DataUpdaterPlant.DataUpdater.State

    AMQPTestHelper.clean_queue()

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    DatabaseTestHelper.insert_device(realm, device_id)

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

  test "a disconnected device does not generate a disconnection trigger", %{realm: realm} do
    AMQPTestHelper.clean_queue()

    encoded_device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    {:ok, device_id} = Device.decode_device_id(encoded_device_id)

    DatabaseTestHelper.insert_device(realm, device_id)

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
             generate_trigger_target()
           ) == :ok

    DataUpdater.handle_disconnection(
      realm,
      encoded_device_id,
      gen_tracking_id(),
      timestamp_us_x_10
    )

    # Receive the first disconnection trigger
    {event, headers, _metadata} = AMQPTestHelper.wait_and_get_message()
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
    assert AMQPTestHelper.awaiting_messages_count() == 0
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

  defp generate_trigger_target() do
    %TriggerTargetContainer{
      trigger_target: {
        :amqp_trigger_target,
        %AMQPTriggerTarget{
          routing_key: AMQPTestHelper.events_routing_key()
        }
      }
    }
    |> TriggerTargetContainer.encode()
  end

  defp retrieve_endpoint_id(realm_name, interface_name, interface_major, path) do
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from i in Interface,
        prefix: ^keyspace_name,
        where: i.name == ^interface_name and i.major_version == ^interface_major,
        select: %{
          automaton_transitions: i.automaton_transitions,
          automaton_accepting_states: i.automaton_accepting_states
        }

    interface_row = Repo.one!(query)

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
