defmodule Astarte.Core.SimpleEventsTest do
  use ExUnit.Case

  describe "payload serialized with ExProtobuf" do
    test "still works for DeviceConnectedEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.DeviceConnectedEvent

      serialized_event = <<10, 9, 49, 50, 51, 46, 49, 46, 50, 46, 51>>

      ip = "123.1.2.3"

      event = %DeviceConnectedEvent{
        device_ip_address: ip
      }

      assert DeviceConnectedEvent.encode(event) == serialized_event
      assert DeviceConnectedEvent.decode(serialized_event) == event
    end

    test "still works for DeviceDisconnectedEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.DeviceDisconnectedEvent

      serialized_event = <<>>
      event = %DeviceDisconnectedEvent{}

      assert DeviceDisconnectedEvent.encode(event) == serialized_event
      assert DeviceDisconnectedEvent.decode(serialized_event) == event
    end

    test "still works for DeviceErrorEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.DeviceErrorEvent

      serialized_event =
        <<10, 21, 105, 110, 118, 97, 108, 105, 100, 95, 105, 110, 116, 114, 111, 115, 112, 101,
          99, 116, 105, 111, 110, 18, 42, 10, 14, 98, 97, 115, 101, 54, 52, 95, 112, 97, 121, 108,
          111, 97, 100, 18, 24, 98, 109, 57, 48, 89, 87, 53, 112, 98, 110, 82, 121, 98, 51, 78,
          119, 90, 87, 78, 48, 97, 87, 57, 117>>

      error_name = "invalid_introspection"
      metadata_map = %{"base64_payload" => Base.encode64("notanintrospection")}

      event = %DeviceErrorEvent{
        error_name: error_name,
        metadata: metadata_map
      }

      assert DeviceErrorEvent.encode(event) == serialized_event
      assert DeviceErrorEvent.decode(serialized_event) == event
    end

    test "still works for DeviceRegisteredEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.DeviceRegisteredEvent

      serialized_event = <<>>
      event = %DeviceRegisteredEvent{}

      assert DeviceRegisteredEvent.encode(event) == serialized_event
      assert DeviceRegisteredEvent.decode(serialized_event) == event
    end

    test "still works for DeviceDeletionStartedEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.DeviceDeletionStartedEvent

      serialized_event = <<>>
      event = %DeviceDeletionStartedEvent{}

      assert DeviceDeletionStartedEvent.encode(event) == serialized_event
      assert DeviceDeletionStartedEvent.decode(serialized_event) == event
    end

    test "still works for DeviceDeletionFinishedEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.DeviceDeletionFinishedEvent

      serialized_event = <<>>
      event = %DeviceDeletionFinishedEvent{}

      assert DeviceDeletionFinishedEvent.encode(event) == serialized_event
      assert DeviceDeletionFinishedEvent.decode(serialized_event) == event
    end

    test "still works for IncomingDataEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 18, 7, 47, 97, 47, 112, 97, 116, 104, 26, 12, 12, 0, 0, 0, 16, 118, 0,
          42, 0, 0, 0, 0>>

      interface = "com.example.Interface"
      path = "/a/path"
      value = 42
      bson_value = Cyanide.encode!(%{v: value})

      event = %IncomingDataEvent{
        interface: interface,
        path: path,
        bson_value: bson_value
      }

      assert IncomingDataEvent.encode(event) == serialized_event
      assert IncomingDataEvent.decode(serialized_event) == event
    end

    test "still works for IncomingDataEvent with empty bson_value (e.g. unset)" do
      alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 18, 13, 47, 97, 110, 111, 116, 104, 101, 114, 47, 112, 97, 116, 104,
          26, 0>>

      interface = "com.example.Interface"
      path = "/another/path"
      bson_value = <<>>

      event = %IncomingDataEvent{
        interface: interface,
        path: path,
        bson_value: bson_value
      }

      assert IncomingDataEvent.encode(event) == serialized_event
      assert IncomingDataEvent.decode(serialized_event) == event
    end

    test "still works for IncomingDataEvent with nil bson_value (e.g. unset)" do
      alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 18, 13, 47, 97, 110, 111, 116, 104, 101, 114, 47, 112, 97, 116, 104>>

      interface = "com.example.Interface"
      path = "/another/path"
      value = nil

      event = %IncomingDataEvent{
        interface: interface,
        path: path,
        bson_value: value
      }

      assert IncomingDataEvent.encode(event) == serialized_event
      assert IncomingDataEvent.decode(serialized_event) == event
    end

    test "still works for IncomingDataEvent with binaryblob bson_value" do
      alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 18, 13, 47, 97, 110, 111, 116, 104, 101, 114, 47, 112, 97, 116, 104,
          26, 17, 17, 0, 0, 0, 5, 118, 0, 4, 0, 0, 0, 0, 1, 2, 3, 230, 0>>

      interface = "com.example.Interface"
      path = "/another/path"
      value = <<1, 2, 3, 230>>
      bson_value = Cyanide.encode!(%{v: {0, value}})

      event = %IncomingDataEvent{
        interface: interface,
        path: path,
        bson_value: bson_value
      }

      assert IncomingDataEvent.encode(event) == serialized_event
      assert IncomingDataEvent.decode(serialized_event) == event
    end

    test "still works for IncomingDataEvent with datetime bson_value" do
      alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 18, 13, 47, 97, 110, 111, 116, 104, 101, 114, 47, 112, 97, 116, 104,
          26, 16, 16, 0, 0, 0, 9, 118, 0, 216, 203, 157, 226, 132, 1, 0, 0, 0>>

      value = DateTime.from_unix!(1_670_249_303)
      interface = "com.example.Interface"
      path = "/another/path"
      bson_value = Cyanide.encode!(%{v: value})

      event = %IncomingDataEvent{
        interface: interface,
        path: path,
        bson_value: bson_value
      }

      assert IncomingDataEvent.encode(event) == serialized_event
      assert IncomingDataEvent.decode(serialized_event) == event
    end

    test "still works for IncomingDataEvent with binaryblobarray bson_value" do
      alias Astarte.Core.Triggers.SimpleEvents.IncomingDataEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 18, 13, 47, 97, 110, 111, 116, 104, 101, 114, 47, 112, 97, 116, 104,
          26, 37, 37, 0, 0, 0, 4, 118, 0, 29, 0, 0, 0, 5, 48, 0, 4, 0, 0, 0, 0, 1, 2, 3, 230, 5,
          49, 0, 4, 0, 0, 0, 0, 4, 5, 6, 230, 0, 0>>

      interface = "com.example.Interface"
      path = "/another/path"
      values = [<<1, 2, 3, 230>>, <<4, 5, 6, 230>>]
      wrapped_values = values |> Enum.map(&{0, &1})
      bson_value = Cyanide.encode!(%{v: wrapped_values})

      event = %IncomingDataEvent{
        interface: interface,
        path: path,
        bson_value: bson_value
      }

      assert IncomingDataEvent.encode(event) == serialized_event
      assert IncomingDataEvent.decode(serialized_event) == event
    end

    test "still works for IncomingIntrospectionEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.IncomingIntrospectionEvent

      serialized_event =
        <<10, 58, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 58, 48, 58, 50, 59, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108,
          101, 46, 65, 110, 111, 116, 104, 101, 114, 73, 110, 116, 101, 114, 102, 97, 99, 101, 58,
          49, 58, 49>>

      introspection = "com.example.Interface:0:2;com.example.AnotherInterface:1:1"

      event = %IncomingIntrospectionEvent{
        introspection: introspection
      }

      assert IncomingIntrospectionEvent.encode(event) == serialized_event
      assert IncomingIntrospectionEvent.decode(serialized_event) == event
    end

    test "still works for InterfaceAddedEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.InterfaceAddedEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 16, 1, 24, 2>>

      interface = "com.example.Interface"
      major_version = 1
      minor_version = 2

      event = %InterfaceAddedEvent{
        interface: interface,
        major_version: major_version,
        minor_version: minor_version
      }

      assert InterfaceAddedEvent.encode(event) == serialized_event
      assert InterfaceAddedEvent.decode(serialized_event) == event
    end

    test "still works for InterfaceMinorUpdatedEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.InterfaceMinorUpdatedEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 16, 1, 24, 2, 32, 3>>

      interface = "com.example.Interface"
      major_version = 1
      old_minor_version = 2
      new_minor_version = 3

      event = %InterfaceMinorUpdatedEvent{
        interface: interface,
        major_version: major_version,
        old_minor_version: old_minor_version,
        new_minor_version: new_minor_version
      }

      assert InterfaceMinorUpdatedEvent.encode(event) == serialized_event
      assert InterfaceMinorUpdatedEvent.decode(serialized_event) == event
    end

    test "still works for InterfaceRemovedEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.InterfaceRemovedEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 16, 1>>

      interface = "com.example.Interface"
      major_version = 1

      event = %InterfaceRemovedEvent{
        interface: interface,
        major_version: major_version
      }

      assert InterfaceRemovedEvent.encode(event) == serialized_event
      assert InterfaceRemovedEvent.decode(serialized_event) == event
    end

    test "still works for PathCreatedEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.PathCreatedEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 18, 10, 47, 115, 111, 109, 101, 47, 112, 97, 116, 104, 26, 27, 27, 0,
          0, 0, 2, 118, 0, 15, 0, 0, 0, 97, 32, 115, 116, 114, 105, 110, 103, 32, 118, 97, 108,
          117, 101, 0, 0>>

      interface = "com.example.Interface"
      path = "/some/path"
      value = "a string value"
      bson_value = Cyanide.encode!(%{v: value})

      event = %PathCreatedEvent{
        interface: interface,
        path: path,
        bson_value: bson_value
      }

      assert PathCreatedEvent.encode(event) == serialized_event
      assert PathCreatedEvent.decode(serialized_event) == event
    end

    test "still works for PathRemovedEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.PathRemovedEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 18, 10, 47, 115, 111, 109, 101, 47, 112, 97, 116, 104>>

      interface = "com.example.Interface"
      path = "/some/path"

      event = %PathRemovedEvent{
        interface: interface,
        path: path
      }

      assert PathRemovedEvent.encode(event) == serialized_event
      assert PathRemovedEvent.decode(serialized_event) == event
    end

    test "still works for ValueChangeAppliedEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.ValueChangeAppliedEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 18, 11, 47, 115, 111, 109, 101, 47, 118, 97, 108, 117, 101, 26, 16,
          16, 0, 0, 0, 1, 118, 0, 205, 204, 204, 204, 204, 204, 0, 64, 0, 34, 16, 16, 0, 0, 0, 1,
          118, 0, 102, 102, 102, 102, 102, 102, 16, 64, 0>>

      interface = "com.example.Interface"
      path = "/some/value"
      old_value = 2.1
      new_value = 4.1
      old_bson_value = Cyanide.encode!(%{v: old_value})
      new_bson_value = Cyanide.encode!(%{v: new_value})

      event = %ValueChangeAppliedEvent{
        interface: interface,
        path: path,
        old_bson_value: old_bson_value,
        new_bson_value: new_bson_value
      }

      assert ValueChangeAppliedEvent.encode(event) == serialized_event
      assert ValueChangeAppliedEvent.decode(serialized_event) == event
    end

    test "still works for ValueChangeEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.ValueChangeEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 18, 11, 47, 115, 111, 109, 101, 47, 118, 97, 108, 117, 101, 26, 16,
          16, 0, 0, 0, 1, 118, 0, 205, 204, 204, 204, 204, 204, 0, 64, 0, 34, 16, 16, 0, 0, 0, 1,
          118, 0, 102, 102, 102, 102, 102, 102, 16, 64, 0>>

      interface = "com.example.Interface"
      path = "/some/value"
      old_value = 2.1
      new_value = 4.1
      old_bson_value = Cyanide.encode!(%{v: old_value})
      new_bson_value = Cyanide.encode!(%{v: new_value})

      event = %ValueChangeEvent{
        interface: interface,
        path: path,
        old_bson_value: old_bson_value,
        new_bson_value: new_bson_value
      }

      assert ValueChangeEvent.encode(event) == serialized_event
      assert ValueChangeEvent.decode(serialized_event) == event
    end

    test "still works for ValueStoredEvent" do
      alias Astarte.Core.Triggers.SimpleEvents.ValueStoredEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 18, 11, 47, 115, 111, 109, 101, 47, 118, 97, 108, 117, 101, 26, 17,
          17, 0, 0, 0, 2, 118, 0, 5, 0, 0, 0, 116, 101, 115, 116, 0, 0>>

      interface = "com.example.Interface"
      path = "/some/value"
      value = "test"
      bson_value = Cyanide.encode!(%{v: value})

      event = %ValueStoredEvent{
        interface: interface,
        path: path,
        bson_value: bson_value
      }

      assert ValueStoredEvent.encode(event) == serialized_event
      assert ValueStoredEvent.decode(serialized_event) == event
    end

    test "still works for ValueStoredEvent with old-format aggregate bson value" do
      alias Astarte.Core.Triggers.SimpleEvents.ValueStoredEvent

      serialized_event =
        <<10, 21, 99, 111, 109, 46, 101, 120, 97, 109, 112, 108, 101, 46, 73, 110, 116, 101, 114,
          102, 97, 99, 101, 18, 11, 47, 115, 111, 109, 101, 47, 118, 97, 108, 117, 101, 26, 54,
          54, 0, 0, 0, 2, 111, 108, 100, 0, 7, 0, 0, 0, 102, 111, 114, 109, 97, 116, 0, 2, 115,
          111, 109, 101, 0, 10, 0, 0, 0, 97, 103, 103, 114, 101, 103, 97, 116, 101, 0, 16, 118,
          101, 114, 115, 105, 111, 110, 0, 42, 0, 0, 0, 0>>

      interface = "com.example.Interface"
      path = "/some/value"
      old_format_value = %{"some" => "aggregate", "old" => "format", "version" => 42}
      bson_value = Cyanide.encode!(old_format_value)

      event = %ValueStoredEvent{
        interface: interface,
        path: path,
        bson_value: bson_value
      }

      assert ValueStoredEvent.encode(event) == serialized_event
      assert ValueStoredEvent.decode(serialized_event) == event
    end
  end

  describe "IncomingIntrospectionEvent" do
    alias Astarte.Core.Triggers.SimpleEvents.IncomingIntrospectionEvent

    test "is correctly serialized when payload is a string" do
      introspection_string = "com.an.Interface:1:0;com.another.Interface:0:1"

      event = %IncomingIntrospectionEvent{introspection: introspection_string}

      assert ^event =
               IncomingIntrospectionEvent.encode(event) |> IncomingIntrospectionEvent.decode()
    end

    test "is correctly serialized when payload is a map" do
      alias Astarte.Core.Triggers.SimpleEvents.InterfaceVersion

      introspection_map = %{
        "com.an.Interface" => %InterfaceVersion{major: 1, minor: 0},
        "com.another.Interface" => %InterfaceVersion{major: 0, minor: 1}
      }

      event = %IncomingIntrospectionEvent{introspection_map: introspection_map}

      assert ^event =
               IncomingIntrospectionEvent.encode(event) |> IncomingIntrospectionEvent.decode()
    end
  end
end
