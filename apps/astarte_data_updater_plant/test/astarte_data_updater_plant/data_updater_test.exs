#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.DataUpdaterPlant.DataUpdaterTest do
  use ExUnit.Case
  alias Astarte.Core.Triggers.SimpleEvents.DeviceConnectedEvent
  alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent
  alias Astarte.Core.Triggers.SimpleEvents.InterfaceAddedEvent
  alias Astarte.Core.Triggers.SimpleEvents.PathRemovedEvent
  alias Astarte.Core.Triggers.SimpleEvents.SimpleEvent
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.DataUpdaterPlant.AMQPTestHelper
  alias Astarte.DataUpdaterPlant.DatabaseTestHelper
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.Core.CQLUtils
  alias CQEx.Client, as: DatabaseClient
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult

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
    device_id = "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ"
    device_id_uuid = DatabaseTestHelper.extended_id_to_uuid(device_id)
    short_device_id = "f0VMRgIBAQAAAAAAAAAAAA"

    received_msgs = 45000
    received_bytes = 4_500_000
    existing_introspection_map = %{"com.test.LCDMonitor" => 1, "com.test.SimpleStreamTest" => 1}
    existing_introspection_string = "com.test.LCDMonitor:1:0;com.test.SimpleStreamTest:1:0"

    insert_opts = [
      introspection: existing_introspection_map,
      total_received_msgs: received_msgs,
      total_received_bytes: received_bytes
    ]

    DatabaseTestHelper.insert_device(device_id, insert_opts)

    db_client = connect_to_db(realm)

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
             device_id,
             device_id_uuid,
             1,
             volatile_trigger_parent_id,
             volatile_trigger_id,
             simple_trigger_data,
             trigger_target_data
           ) == :ok

    assert DataUpdater.handle_delete_volatile_trigger(realm, device_id, volatile_trigger_id) ==
             :ok

    DataUpdater.handle_connection(
      realm,
      device_id,
      "10.0.0.1",
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:00:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)
    {conn_event, conn_headers, _metadata} = AMQPTestHelper.wait_and_get_message()
    assert conn_headers["x_astarte_event_type"] == "device_connected_event"
    assert conn_headers["x_astarte_realm"] == realm
    assert conn_headers["x_astarte_device_id"] == short_device_id

    assert :uuid.string_to_uuid(conn_headers["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(conn_headers["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.device_connected_trigger_id()

    assert SimpleEvent.decode(conn_event) == %SimpleEvent{
             device_id: short_device_id,
             event: {
               :device_connected_event,
               %DeviceConnectedEvent{
                 device_ip_address: "10.0.0.1"
               }
             },
             parent_trigger_id: DatabaseTestHelper.fake_parent_trigger_id(),
             realm: realm,
             simple_trigger_id: DatabaseTestHelper.device_connected_trigger_id(),
             version: 1
           }

    device_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT connected, total_received_msgs, total_received_bytes FROM devices WHERE device_id=:device_id;"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)

    device_row =
      DatabaseQuery.call!(db_client, device_query)
      |> DatabaseResult.head()

    assert device_row == [
             connected: true,
             total_received_msgs: 45000,
             total_received_bytes: 4_500_000
           ]

    # Introspection sub-test
    device_introspection_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT introspection FROM devices WHERE device_id=:device_id;")
      |> DatabaseQuery.put(:device_id, device_id_uuid)

    ^existing_introspection_map =
      DatabaseQuery.call!(db_client, device_introspection_query)
      |> DatabaseResult.head()
      |> Keyword.get(:introspection)
      |> Enum.into(%{})

    DataUpdater.handle_introspection(
      realm,
      device_id,
      existing_introspection_string,
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:00:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

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
            known_value: Bson.encode(%{v: 100})
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
             device_id,
             :uuid.string_to_uuid("d2d90d55-a779-b988-9db4-15284b04f2e9"),
             2,
             volatile_trigger_parent_id,
             volatile_trigger_id,
             simple_trigger_data,
             trigger_target_data
           ) == :ok

    # Incoming data sub-test
    DataUpdater.handle_data(
      realm,
      device_id,
      "com.test.LCDMonitor",
      "/time/from",
      Bson.encode(%{"v" => 9000}),
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:10:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.test.LCDMonitor",
      "/weekSchedule/9/start",
      Bson.encode(%{"v" => 9}),
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:10:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.test.LCDMonitor",
      "/weekSchedule/10/start",
      Bson.encode(%{"v" => 10}),
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:10:32+00:00"), 1), :milliseconds) *
        10000
    )

    {incoming_event, incoming_headers, _meta} = AMQPTestHelper.wait_and_get_message()
    assert incoming_headers["x_astarte_event_type"] == "incoming_data_event"
    assert incoming_headers["x_astarte_device_id"] == short_device_id
    assert incoming_headers["x_astarte_realm"] == realm

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(incoming_headers["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.greater_than_incoming_trigger_id()

    assert SimpleEvent.decode(incoming_event) == %SimpleEvent{
             device_id: short_device_id,
             event: {
               :incoming_data_event,
               %IncomingDataEvent{
                 bson_value: Bson.encode(%{"v" => 10}),
                 interface: "com.test.LCDMonitor",
                 path: "/weekSchedule/10/start"
               }
             },
             parent_trigger_id: DatabaseTestHelper.fake_parent_trigger_id(),
             realm: realm,
             simple_trigger_id: DatabaseTestHelper.greater_than_incoming_trigger_id(),
             version: 1
           }

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.test.SimpleStreamTest",
      "/0/value",
      Bson.encode(%{"v" => 5}),
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:15:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

    {incoming_volatile_event, incoming_volatile_headers, _meta} =
      AMQPTestHelper.wait_and_get_message()

    assert incoming_volatile_headers["x_astarte_event_type"] == "incoming_data_event"
    assert incoming_volatile_headers["x_astarte_device_id"] == short_device_id
    assert incoming_volatile_headers["x_astarte_realm"] == realm

    assert :uuid.string_to_uuid(incoming_volatile_headers["x_astarte_parent_trigger_id"]) ==
             volatile_trigger_parent_id

    assert :uuid.string_to_uuid(incoming_volatile_headers["x_astarte_simple_trigger_id"]) ==
             volatile_trigger_id

    assert SimpleEvent.decode(incoming_volatile_event) == %SimpleEvent{
             device_id: short_device_id,
             event:
               {:incoming_data_event,
                %IncomingDataEvent{
                  bson_value: Bson.encode(%{"v" => 5}),
                  interface: "com.test.SimpleStreamTest",
                  path: "/0/value"
                }},
             parent_trigger_id: volatile_trigger_parent_id,
             realm: realm,
             simple_trigger_id: volatile_trigger_id,
             version: 1
           }

    endpoint_id = retrieve_endpoint_id(db_client, "com.test.LCDMonitor", 1, "/time/from")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT longinteger_value FROM individual_property WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)
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
        "SELECT integer_value FROM individual_datastream WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path AND value_timestamp>=:value_timestamp"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.SimpleStreamTest", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/0/value")
      |> DatabaseQuery.put(:value_timestamp, 1_507_557_632_000)

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == [integer_value: 5]

    assert DataUpdater.handle_delete_volatile_trigger(realm, device_id, volatile_trigger_id) ==
             :ok

    # Introspection change subtest
    DataUpdater.handle_introspection(
      realm,
      device_id,
      "com.test.LCDMonitor:1:0;com.example.TestObject:1:5;com.test.SimpleStreamTest:1:0",
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:00:32+00:00"), 1), :milliseconds) *
        10000
    )

    {introspection_event, introspection_headers, _meta} = AMQPTestHelper.wait_and_get_message()
    assert introspection_headers["x_astarte_event_type"] == "interface_added_event"
    assert introspection_headers["x_astarte_realm"] == realm
    assert introspection_headers["x_astarte_device_id"] == short_device_id

    assert :uuid.string_to_uuid(introspection_headers["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(introspection_headers["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.interface_added_trigger_id()

    assert SimpleEvent.decode(introspection_event) == %SimpleEvent{
             device_id: short_device_id,
             event: {
               :interface_added_event,
               %InterfaceAddedEvent{
                 interface: "com.example.TestObject",
                 major_version: 1,
                 minor_version: 5
               }
             },
             parent_trigger_id: DatabaseTestHelper.fake_parent_trigger_id(),
             realm: realm,
             simple_trigger_id: DatabaseTestHelper.interface_added_trigger_id(),
             version: 1
           }

    # Incoming object aggregation subtest
    payload0 = Bson.encode(%{"value" => 1.9, "string" => "Astarteです"})

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.example.TestObject",
      "/",
      payload0,
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-26T08:48:49+00:00"), 1), :milliseconds) *
        10000
    )

    payload1 = Bson.encode(%{"string" => "Hello World');"})

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.example.TestObject",
      "/",
      payload1,
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-26T08:48:50+00:00"), 1), :milliseconds) *
        10000
    )

    payload2 = Bson.encode(%{"v" => %{"value" => 0}})

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.example.TestObject",
      "/",
      payload2,
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-26T08:48:51+00:00"), 1), :milliseconds) *
        10000
    )

    # we expect only /string to be updated here, we need this to check against accidental NULL insertions, that are bad for tombstones on cassandra.
    payload3 = Bson.encode(%{"string" => "zzz"})

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.example.TestObject",
      "/",
      payload3,
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-09-30T07:13:00+00:00"), 1), :milliseconds) *
        10000
    )

    payload4 = Bson.encode(%{})

    DataUpdater.handle_data(
      realm,
      device_id,
      "com.example.TestObject",
      "/",
      payload4,
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-30T07:13:00+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

    objects_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT * FROM com_example_testobject_v1 WHERE device_id=:device_id AND path='/'"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)

    objects =
      DatabaseQuery.call!(db_client, objects_query)
      |> Enum.to_list()

    assert objects == [
             [
               device_id: device_id_uuid,
               path: "/",
               reception_timestamp: 1_506_755_400_000,
               reception_timestamp_submillis: 0,
               string: "aaa",
               value: 1.1
             ],
             [
               device_id: device_id_uuid,
               path: "/",
               reception_timestamp: 1_506_755_520_000,
               reception_timestamp_submillis: 0,
               string: "bbb",
               value: 2.2
             ],
             [
               device_id: device_id_uuid,
               path: "/",
               reception_timestamp: 1_506_755_580_000,
               reception_timestamp_submillis: 0,
               string: "zzz",
               value: 3.3
             ],
             [
               device_id: device_id_uuid,
               path: "/",
               reception_timestamp: 1_509_007_729_000,
               reception_timestamp_submillis: 0,
               string: "Astarteです",
               value: 1.9
             ],
             [
               device_id: device_id_uuid,
               path: "/",
               reception_timestamp: 1_509_007_730_000,
               reception_timestamp_submillis: 0,
               string: "Hello World');",
               value: nil
             ],
             [
               device_id: device_id_uuid,
               path: "/",
               reception_timestamp: 1_509_007_731_000,
               reception_timestamp_submillis: 0,
               string: nil,
               value: 0.0
             ],
             [
               device_id: device_id_uuid,
               path: "/",
               reception_timestamp: 1_509_347_580_000,
               reception_timestamp_submillis: 0,
               string: nil,
               value: nil
             ]
           ]

    # Test /producer/properties control message
    data =
      <<0, 0, 0, 98>> <>
        :zlib.compress("com.test.LCDMonitor/time/to;com.test.LCDMonitor/weekSchedule/10/start")

    DataUpdater.handle_control(
      realm,
      device_id,
      "/producer/properties",
      data,
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:00:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)
    {remove_event, remove_headers, _meta} = AMQPTestHelper.wait_and_get_message()
    assert remove_headers["x_astarte_event_type"] == "path_removed_event"
    assert remove_headers["x_astarte_device_id"] == short_device_id
    assert remove_headers["x_astarte_realm"] == "autotestrealm"

    assert :uuid.string_to_uuid(remove_headers["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(remove_headers["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.path_removed_trigger_id()

    assert SimpleEvent.decode(remove_event) == %SimpleEvent{
             device_id: short_device_id,
             event:
               {:path_removed_event,
                %PathRemovedEvent{interface: "com.test.LCDMonitor", path: "/time/from"}},
             parent_trigger_id: DatabaseTestHelper.fake_parent_trigger_id(),
             realm: "autotestrealm",
             simple_trigger_id: DatabaseTestHelper.path_removed_trigger_id(),
             version: 1
           }

    endpoint_id = retrieve_endpoint_id(db_client, "com.test.LCDMonitor", 1, "/time/from")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT longinteger_value FROM individual_property WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)
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
        "SELECT longinteger_value FROM individual_property WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)
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
        "SELECT longinteger_value FROM individual_property WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)
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
        "SELECT integer_value FROM individual_datastream WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path AND value_timestamp>=:value_timestamp"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)
      |> DatabaseQuery.put(:interface_id, CQLUtils.interface_id("com.test.SimpleStreamTest", 1))
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, "/0/value")
      |> DatabaseQuery.put(:value_timestamp, 1_507_557_632_000)

    value =
      DatabaseQuery.call!(db_client, value_query)
      |> DatabaseResult.head()

    assert value == [integer_value: 5]

    # Unset subtest
    DataUpdater.handle_data(
      realm,
      device_id,
      "com.test.LCDMonitor",
      "/weekSchedule/10/start",
      <<>>,
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T15:10:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

    endpoint_id =
      retrieve_endpoint_id(db_client, "com.test.LCDMonitor", 1, "/weekSchedule/10/start")

    value_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT longinteger_value FROM individual_property WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id_uuid)
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
      device_id,
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:30:45+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

    device_row =
      DatabaseQuery.call!(db_client, device_query)
      |> DatabaseResult.head()

    assert device_row == [
             connected: false,
             total_received_msgs: 45013,
             total_received_bytes: 4_500_692
           ]

    assert AMQPTestHelper.awaiting_messages_count() == 0
  end

  test "empty introspection is updated correctly" do
    AMQPTestHelper.clean_queue()

    realm = "autotestrealm"

    device_id =
      :crypto.strong_rand_bytes(16)
      |> Base.url_encode64(padding: false)

    device_id_uuid = DatabaseTestHelper.extended_id_to_uuid(device_id)
    new_introspection_map = %{"com.test.LCDMonitor" => 1, "com.test.SimpleStreamTest" => 1}
    new_introspection_string = "com.test.LCDMonitor:1:0;com.test.SimpleStreamTest:1:0"

    DatabaseTestHelper.insert_device(device_id)

    db_client = connect_to_db(realm)

    DataUpdater.handle_connection(
      realm,
      device_id,
      "10.0.0.1",
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-12-09T14:00:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)

    device_introspection_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT introspection FROM devices WHERE device_id=:device_id;")
      |> DatabaseQuery.put(:device_id, device_id_uuid)

    old_device_introspection =
      DatabaseQuery.call!(db_client, device_introspection_query)
      |> DatabaseResult.head()
      |> Keyword.get(:introspection)

    assert old_device_introspection == nil

    DataUpdater.handle_introspection(
      realm,
      device_id,
      new_introspection_string,
      gen_tracking_id(),
      DateTime.to_unix(elem(DateTime.from_iso8601("2017-10-09T14:00:32+00:00"), 1), :milliseconds) *
        10000
    )

    DataUpdater.dump_state(realm, device_id)
    {event_data1, event_headers1, _metadata} = AMQPTestHelper.wait_and_get_message()
    assert event_headers1["x_astarte_event_type"] == "interface_added_event"
    assert event_headers1["x_astarte_realm"] == realm
    assert event_headers1["x_astarte_device_id"] == device_id

    assert :uuid.string_to_uuid(event_headers1["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(event_headers1["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.interface_added_trigger_id()

    assert SimpleEvent.decode(event_data1) == %SimpleEvent{
             device_id: device_id,
             event: {
               :interface_added_event,
               %InterfaceAddedEvent{
                 interface: "com.test.LCDMonitor",
                 major_version: 1,
                 minor_version: 0
               }
             },
             parent_trigger_id: DatabaseTestHelper.fake_parent_trigger_id(),
             realm: realm,
             simple_trigger_id: DatabaseTestHelper.interface_added_trigger_id(),
             version: 1
           }

    {event_data2, event_headers2, _metadata} = AMQPTestHelper.wait_and_get_message()
    assert event_headers2["x_astarte_event_type"] == "interface_added_event"
    assert event_headers2["x_astarte_realm"] == realm
    assert event_headers2["x_astarte_device_id"] == device_id

    assert :uuid.string_to_uuid(event_headers2["x_astarte_parent_trigger_id"]) ==
             DatabaseTestHelper.fake_parent_trigger_id()

    assert :uuid.string_to_uuid(event_headers2["x_astarte_simple_trigger_id"]) ==
             DatabaseTestHelper.interface_added_trigger_id()

    assert SimpleEvent.decode(event_data2) == %SimpleEvent{
             device_id: device_id,
             event: {
               :interface_added_event,
               %InterfaceAddedEvent{
                 interface: "com.test.SimpleStreamTest",
                 major_version: 1,
                 minor_version: 0
               }
             },
             parent_trigger_id: DatabaseTestHelper.fake_parent_trigger_id(),
             realm: realm,
             simple_trigger_id: DatabaseTestHelper.interface_added_trigger_id(),
             version: 1
           }

    new_device_introspection =
      DatabaseQuery.call!(db_client, device_introspection_query)
      |> DatabaseResult.head()
      |> Keyword.get(:introspection)
      |> Enum.into(%{})

    assert new_device_introspection == new_introspection_map

    assert AMQPTestHelper.awaiting_messages_count() == 0
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

  defp connect_to_db(realm) do
    DatabaseClient.new!(
      List.first(Application.get_env(:cqerl, :cassandra_nodes)),
      keyspace: realm
    )
  end

  defp gen_tracking_id() do
    message_id = :erlang.unique_integer([:monotonic]) |> Integer.to_string()
    delivery_tag = {:injected_msg, make_ref()}
    {message_id, delivery_tag}
  end
end
