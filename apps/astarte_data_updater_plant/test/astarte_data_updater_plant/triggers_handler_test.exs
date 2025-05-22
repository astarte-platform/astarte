#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.DataUpdaterPlant.TriggersHandlerTest do
  use ExUnit.Case

  alias Astarte.Core.Triggers.SimpleEvents.{
    DeviceConnectedEvent,
    DeviceDisconnectedEvent,
    DeviceErrorEvent,
    IncomingDataEvent,
    IncomingIntrospectionEvent,
    InterfaceAddedEvent,
    InterfaceMinorUpdatedEvent,
    InterfaceRemovedEvent,
    InterfaceVersion,
    PathCreatedEvent,
    PathRemovedEvent,
    SimpleEvent,
    ValueChangeAppliedEvent,
    ValueChangeEvent,
    ValueStoredEvent
  }

  alias AMQP.Channel
  alias AMQP.Connection
  alias AMQP.Queue
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataUpdaterPlant.TriggersHandler

  @introspection "com.My.Interface:1:0;com.Another.Interface:1:2"
  @introspection_map %{
    "com.My.Interface" => %InterfaceVersion{major: 1, minor: 0},
    "com.Another.Interface" => %InterfaceVersion{major: 1, minor: 2}
  }
  @queue_name "test_events_queue"
  @routing_key "test_routing_key"
  @realm "autotestrealm"
  @device_id :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  @interface "com.Test.Interface"
  @major_version 1
  @minor_version 1
  @path "/some/path"
  @bson_value %{v: "testvalue"} |> Cyanide.encode!()
  @ip_address "2.3.4.5"

  @default_policy_name "@default"
  @default_policy_queue "#{@realm}_#{@default_policy_name}_queue"
  @default_policy_routing_key "#{@realm}_#{@default_policy_name}"
  @custom_policy_name "such_a_nice_policy"
  @custom_policy_queue "#{@realm}_#{@custom_policy_name}_queue"
  @custom_policy_routing_key "#{@realm}_#{@custom_policy_name}"

  setup_all do
    {:ok, conn} = Connection.open(Config.amqp_producer_options!())
    {:ok, chan} = Channel.open(conn)
    {:ok, _queue} = Queue.declare(chan, @queue_name)
    {:ok, _queue} = Queue.declare(chan, @default_policy_queue)
    {:ok, _queue} = Queue.declare(chan, @custom_policy_queue)
    :ok = Queue.bind(chan, @queue_name, Config.events_exchange_name!(), routing_key: @routing_key)

    :ok =
      Queue.bind(chan, @default_policy_queue, Config.events_exchange_name!(),
        routing_key: @default_policy_routing_key
      )

    :ok =
      Queue.bind(chan, @custom_policy_queue, Config.events_exchange_name!(),
        routing_key: @custom_policy_routing_key
      )

    on_exit(fn ->
      Channel.close(chan)
      Connection.close(conn)
    end)

    [chan: chan]
  end

  describe "AMQPTarget handling" do
    setup %{chan: chan} do
      consumer_tag = subscribe_to_queue(chan, @queue_name)

      on_exit(fn ->
        AMQP.Queue.unsubscribe(chan, consumer_tag)
      end)
    end

    test "device_connected AMQPTarget handling" do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_connected"
      static_header_value = "test_meta_connected"
      static_headers = [{static_header_key, static_header_value}]
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

      TriggersHandler.device_connected(target, @realm, @device_id, @ip_address, timestamp, nil)

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:device_connected_event, device_connected_event}
             } = SimpleEvent.decode(payload)

      assert %DeviceConnectedEvent{
               device_ip_address: @ip_address
             } = device_connected_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "device_connected_event"
      assert Map.get(headers_map, static_header_key) == static_header_value
    end

    test "device_error AMQPTarget handling" do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_error"
      static_header_value = "test_meta_error"
      static_headers = [{static_header_key, static_header_value}]
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

      error_metadata = %{"base64_payload" => Base.encode64("aninvalidintrospection")}

      TriggersHandler.device_error(
        target,
        @realm,
        @device_id,
        "invalid_introspection",
        error_metadata,
        timestamp,
        nil
      )

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:device_error_event, device_error_event}
             } = SimpleEvent.decode(payload)

      assert %DeviceErrorEvent{
               error_name: error_name,
               metadata: metadata
             } = device_error_event

      assert error_name == "invalid_introspection"
      assert metadata |> Enum.into(%{}) == error_metadata

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "device_error_event"
      assert Map.get(headers_map, static_header_key) == static_header_value
    end

    test "device_disconnected AMQPTarget handling" do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_disconnected"
      static_header_value = "test_meta_disconnected"
      static_headers = [{static_header_key, static_header_value}]
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

      TriggersHandler.device_disconnected(target, @realm, @device_id, timestamp, nil)

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:device_disconnected_event, device_disconnected_event}
             } = SimpleEvent.decode(payload)

      assert %DeviceDisconnectedEvent{} = device_disconnected_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "device_disconnected_event"
      assert Map.get(headers_map, static_header_key) == static_header_value
    end

    test "incoming_data AMQPTarget handling" do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata"
      static_header_value = "test_meta"
      static_headers = [{static_header_key, static_header_value}]
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

      TriggersHandler.incoming_data(
        target,
        @realm,
        @device_id,
        @interface,
        @path,
        @bson_value,
        timestamp,
        nil
      )

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:incoming_data_event, incoming_data_event}
             } = SimpleEvent.decode(payload)

      assert %IncomingDataEvent{
               interface: @interface,
               path: @path,
               bson_value: @bson_value
             } = incoming_data_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "incoming_data_event"

      assert Map.get(headers_map, "x_astarte_simple_trigger_id") |> :uuid.string_to_uuid() ==
               simple_trigger_id

      assert Map.get(headers_map, "x_astarte_parent_trigger_id") |> :uuid.string_to_uuid() ==
               parent_trigger_id

      assert Map.get(headers_map, static_header_key) == static_header_value
    end

    test "incoming_introspection AMQPTarget handling" do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_incoming_introspection"
      static_header_value = "test_meta_incoming_introspection"
      static_headers = [{static_header_key, static_header_value}]
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

      TriggersHandler.incoming_introspection(
        target,
        @realm,
        @device_id,
        @introspection,
        timestamp,
        nil
      )

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:incoming_introspection_event, incoming_introspection_event}
             } = SimpleEvent.decode(payload)

      assert %IncomingIntrospectionEvent{
               introspection_map: @introspection_map
             } = incoming_introspection_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "incoming_introspection_event"
      assert Map.get(headers_map, static_header_key) == static_header_value
    end

    test "incoming_introspection AMQPTarget handling with legacy event" do
      Config.put_generate_legacy_incoming_introspection_events(true)
      on_exit(fn -> Config.put_generate_legacy_incoming_introspection_events(false) end)
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_incoming_introspection"
      static_header_value = "test_meta_incoming_introspection"
      static_headers = [{static_header_key, static_header_value}]
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

      TriggersHandler.incoming_introspection(
        target,
        @realm,
        @device_id,
        @introspection,
        timestamp,
        nil
      )

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:incoming_introspection_event, incoming_introspection_event}
             } = SimpleEvent.decode(payload)

      assert %IncomingIntrospectionEvent{introspection: @introspection} =
               incoming_introspection_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "incoming_introspection_event"
      assert Map.get(headers_map, static_header_key) == static_header_value
    end

    test "interface_added AMQPTarget handling" do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_interface_added"
      static_header_value = "test_meta_interface_added"
      static_headers = [{static_header_key, static_header_value}]
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

      TriggersHandler.interface_added(
        target,
        @realm,
        @device_id,
        @interface,
        @major_version,
        @minor_version,
        timestamp,
        nil
      )

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:interface_added_event, interface_added_event}
             } = SimpleEvent.decode(payload)

      assert %InterfaceAddedEvent{
               interface: @interface,
               major_version: @major_version,
               minor_version: @minor_version
             } = interface_added_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "interface_added_event"
      assert Map.get(headers_map, static_header_key) == static_header_value
    end

    test "interface_minor_updated AMQPTarget handling" do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_interface_minor_updated"
      static_header_value = "test_meta_interface_minor_updated"
      static_headers = [{static_header_key, static_header_value}]
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

      old_minor_version = @minor_version
      new_minor_version = @minor_version + 2

      TriggersHandler.interface_minor_updated(
        target,
        @realm,
        @device_id,
        @interface,
        @major_version,
        old_minor_version,
        new_minor_version,
        timestamp,
        nil
      )

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:interface_minor_updated_event, interface_minor_updated_event}
             } = SimpleEvent.decode(payload)

      assert %InterfaceMinorUpdatedEvent{
               interface: @interface,
               major_version: @major_version,
               old_minor_version: ^old_minor_version,
               new_minor_version: ^new_minor_version
             } = interface_minor_updated_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "interface_minor_updated_event"
      assert Map.get(headers_map, static_header_key) == static_header_value
    end

    test "interface_removed AMQPTarget handling" do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_interface_removed"
      static_header_value = "test_meta_interface_removed"
      static_headers = [{static_header_key, static_header_value}]
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

      TriggersHandler.interface_removed(
        target,
        @realm,
        @device_id,
        @interface,
        @major_version,
        timestamp,
        nil
      )

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:interface_removed_event, interface_removed_event}
             } = SimpleEvent.decode(payload)

      assert %InterfaceRemovedEvent{
               interface: @interface,
               major_version: @major_version
             } = interface_removed_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "interface_removed_event"
      assert Map.get(headers_map, static_header_key) == static_header_value
    end

    test "path_created AMQPTarget handling" do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_path_created"
      static_header_value = "test_meta_path_created"
      static_headers = [{static_header_key, static_header_value}]
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

      TriggersHandler.path_created(
        target,
        @realm,
        @device_id,
        @interface,
        @path,
        @bson_value,
        timestamp,
        nil
      )

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:path_created_event, path_created_event}
             } = SimpleEvent.decode(payload)

      assert %PathCreatedEvent{
               interface: @interface,
               path: @path,
               bson_value: @bson_value
             } = path_created_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "path_created_event"

      assert Map.get(headers_map, "x_astarte_simple_trigger_id") |> :uuid.string_to_uuid() ==
               simple_trigger_id

      assert Map.get(headers_map, "x_astarte_parent_trigger_id") |> :uuid.string_to_uuid() ==
               parent_trigger_id

      assert Map.get(headers_map, static_header_key) == static_header_value
    end

    test "path_removed AMQPTarget handling" do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_path_removed"
      static_header_value = "test_meta_path_removed"
      static_headers = [{static_header_key, static_header_value}]
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

      TriggersHandler.path_removed(target, @realm, @device_id, @interface, @path, timestamp, nil)

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:path_removed_event, path_removed_event}
             } = SimpleEvent.decode(payload)

      assert %PathRemovedEvent{
               interface: @interface,
               path: @path
             } = path_removed_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "path_removed_event"

      assert Map.get(headers_map, "x_astarte_simple_trigger_id") |> :uuid.string_to_uuid() ==
               simple_trigger_id

      assert Map.get(headers_map, "x_astarte_parent_trigger_id") |> :uuid.string_to_uuid() ==
               parent_trigger_id

      assert Map.get(headers_map, static_header_key) == static_header_value
    end

    test "value_change AMQPTarget handling" do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_value_change"
      static_header_value = "test_meta_value_change"
      static_headers = [{static_header_key, static_header_value}]
      old_bson_value = %{v: 41} |> Cyanide.encode!()
      new_bson_value = %{v: 42} |> Cyanide.encode!()
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

      TriggersHandler.value_change(
        target,
        @realm,
        @device_id,
        @interface,
        @path,
        old_bson_value,
        new_bson_value,
        timestamp,
        nil
      )

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:value_change_event, value_change_event}
             } = SimpleEvent.decode(payload)

      assert %ValueChangeEvent{
               interface: @interface,
               path: @path,
               old_bson_value: ^old_bson_value,
               new_bson_value: ^new_bson_value
             } = value_change_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "value_change_event"

      assert Map.get(headers_map, "x_astarte_simple_trigger_id") |> :uuid.string_to_uuid() ==
               simple_trigger_id

      assert Map.get(headers_map, "x_astarte_parent_trigger_id") |> :uuid.string_to_uuid() ==
               parent_trigger_id

      assert Map.get(headers_map, static_header_key) == static_header_value
    end

    test "value_change_applied AMQPTarget handling" do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_value_change_applied"
      static_header_value = "test_meta_value_change_applied"
      static_headers = [{static_header_key, static_header_value}]
      old_bson_value = %{v: 41} |> Cyanide.encode!()
      new_bson_value = %{v: 42} |> Cyanide.encode!()
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

      TriggersHandler.value_change_applied(
        target,
        @realm,
        @device_id,
        @interface,
        @path,
        old_bson_value,
        new_bson_value,
        timestamp,
        nil
      )

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:value_change_applied_event, value_change_applied_event}
             } = SimpleEvent.decode(payload)

      assert %ValueChangeAppliedEvent{
               interface: @interface,
               path: @path,
               old_bson_value: ^old_bson_value,
               new_bson_value: ^new_bson_value
             } = value_change_applied_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "value_change_applied_event"

      assert Map.get(headers_map, "x_astarte_simple_trigger_id") |> :uuid.string_to_uuid() ==
               simple_trigger_id

      assert Map.get(headers_map, "x_astarte_parent_trigger_id") |> :uuid.string_to_uuid() ==
               parent_trigger_id

      assert Map.get(headers_map, static_header_key) == static_header_value
    end
  end

  describe "trigger policy routing" do
    setup %{chan: chan} do
      default_policy_consumer_tag = subscribe_to_queue(chan, @default_policy_queue)
      custom_policy_consumer_tag = subscribe_to_queue(chan, @custom_policy_queue)
      no_policy_consumer_tag = subscribe_to_queue(chan, @queue_name)

      on_exit(fn ->
        AMQP.Queue.unsubscribe(chan, default_policy_consumer_tag)
        AMQP.Queue.unsubscribe(chan, custom_policy_consumer_tag)
        AMQP.Queue.unsubscribe(chan, no_policy_consumer_tag)
      end)
    end

    test "HTTP trigger with no policy defaults to default one", %{chan: chan} do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_value_change_applied"
      static_header_value = "test_meta_value_change_applied"
      static_headers = [{static_header_key, static_header_value}]
      old_bson_value = %{v: 41} |> Cyanide.encode!()
      new_bson_value = %{v: 42} |> Cyanide.encode!()
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: "trigger_engine"
      }

      TriggersHandler.value_change_applied(
        target,
        @realm,
        @device_id,
        @interface,
        @path,
        old_bson_value,
        new_bson_value,
        timestamp,
        nil
      )

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:value_change_applied_event, value_change_applied_event}
             } = SimpleEvent.decode(payload)

      assert %ValueChangeAppliedEvent{
               interface: @interface,
               path: @path,
               old_bson_value: ^old_bson_value,
               new_bson_value: ^new_bson_value
             } = value_change_applied_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_trigger_policy") == @default_policy_name
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "value_change_applied_event"

      assert Map.get(headers_map, "x_astarte_simple_trigger_id") |> :uuid.string_to_uuid() ==
               simple_trigger_id

      assert Map.get(headers_map, "x_astarte_parent_trigger_id") |> :uuid.string_to_uuid() ==
               parent_trigger_id

      assert Map.get(headers_map, static_header_key) == static_header_value
    end

    test "HTTP trigger with explicit trigger policy is correctly routed", %{chan: chan} do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_value_change_applied"
      static_header_value = "test_meta_value_change_applied"
      static_headers = [{static_header_key, static_header_value}]
      old_bson_value = %{v: 41} |> Cyanide.encode!()
      new_bson_value = %{v: 42} |> Cyanide.encode!()
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: "trigger_engine"
      }

      TriggersHandler.value_change_applied(
        target,
        @realm,
        @device_id,
        @interface,
        @path,
        old_bson_value,
        new_bson_value,
        timestamp,
        @custom_policy_name
      )

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:value_change_applied_event, value_change_applied_event}
             } = SimpleEvent.decode(payload)

      assert %ValueChangeAppliedEvent{
               interface: @interface,
               path: @path,
               old_bson_value: ^old_bson_value,
               new_bson_value: ^new_bson_value
             } = value_change_applied_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_trigger_policy") == @custom_policy_name
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "value_change_applied_event"

      assert Map.get(headers_map, "x_astarte_simple_trigger_id") |> :uuid.string_to_uuid() ==
               simple_trigger_id

      assert Map.get(headers_map, "x_astarte_parent_trigger_id") |> :uuid.string_to_uuid() ==
               parent_trigger_id

      assert Map.get(headers_map, static_header_key) == static_header_value
    end

    test "AMQP trigger has no trigger policy", %{chan: chan} do
      simple_trigger_id = :uuid.get_v4()
      parent_trigger_id = :uuid.get_v4()
      static_header_key = "important_metadata_value_change_applied"
      static_header_value = "test_meta_value_change_applied"
      static_headers = [{static_header_key, static_header_value}]
      old_bson_value = %{v: 41} |> Cyanide.encode!()
      new_bson_value = %{v: 42} |> Cyanide.encode!()
      timestamp = get_timestamp()

      target = %AMQPTriggerTarget{
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: @routing_key
      }

      TriggersHandler.value_change_applied(
        target,
        @realm,
        @device_id,
        @interface,
        @path,
        old_bson_value,
        new_bson_value,
        timestamp,
        nil
      )

      assert_receive {:event, payload, meta}

      assert %SimpleEvent{
               device_id: @device_id,
               parent_trigger_id: ^parent_trigger_id,
               simple_trigger_id: ^simple_trigger_id,
               realm: @realm,
               timestamp: ^timestamp,
               event: {:value_change_applied_event, value_change_applied_event}
             } = SimpleEvent.decode(payload)

      assert %ValueChangeAppliedEvent{
               interface: @interface,
               path: @path,
               old_bson_value: ^old_bson_value,
               new_bson_value: ^new_bson_value
             } = value_change_applied_event

      headers_map = amqp_headers_to_map(meta.headers)

      assert Map.get(headers_map, "x_astarte_realm") == @realm
      assert Map.get(headers_map, "x_astarte_device_id") == @device_id
      assert Map.get(headers_map, "x_astarte_event_type") == "value_change_applied_event"

      assert Map.get(headers_map, "x_astarte_simple_trigger_id") |> :uuid.string_to_uuid() ==
               simple_trigger_id

      assert Map.get(headers_map, "x_astarte_parent_trigger_id") |> :uuid.string_to_uuid() ==
               parent_trigger_id

      assert Map.get(headers_map, static_header_key) == static_header_value
      assert Map.get(headers_map, "x_astarte_trigger_policy") == nil
    end
  end

  defp amqp_headers_to_map(headers) do
    Enum.reduce(headers, %{}, fn {key, _type, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  defp get_timestamp do
    DateTime.utc_now()
    |> DateTime.to_unix(:microsecond)
  end

  defp subscribe_to_queue(chan, queue_name) do
    test_pid = self()

    {:ok, consumer_tag} =
      AMQP.Queue.subscribe(chan, queue_name, fn payload, meta ->
        send(test_pid, {:event, payload, meta})
      end)

    consumer_tag
  end
end
