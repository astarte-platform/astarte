defmodule Astarte.Core.Triggers.SimpleTriggersProtobufTest do
  use ExUnit.Case

  describe "payload serialized with ExProtobuf" do
    test "still works for AMQPTriggerTarget" do
      alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget

      simple_trigger_id = "c0cd4ff8-1ee1-4162-b654-2697f6af652b"
      parent_trigger_id = "825b42ff-6664-4f67-ac64-71a1865acb05"
      static_header_key = "important_metadata_connected"
      static_header_value = "test_meta_connected"
      static_headers = %{static_header_key => static_header_value}
      routing_key = "test_routing_key"

      target = %AMQPTriggerTarget{
        version: 1,
        simple_trigger_id: simple_trigger_id,
        parent_trigger_id: parent_trigger_id,
        static_headers: static_headers,
        routing_key: routing_key
      }

      serialized_target =
        <<8, 1, 18, 36, 99, 48, 99, 100, 52, 102, 102, 56, 45, 49, 101, 101, 49, 45, 52, 49, 54,
          50, 45, 98, 54, 53, 52, 45, 50, 54, 57, 55, 102, 54, 97, 102, 54, 53, 50, 98, 26, 36,
          56, 50, 53, 98, 52, 50, 102, 102, 45, 54, 54, 54, 52, 45, 52, 102, 54, 55, 45, 97, 99,
          54, 52, 45, 55, 49, 97, 49, 56, 54, 53, 97, 99, 98, 48, 53, 34, 16, 116, 101, 115, 116,
          95, 114, 111, 117, 116, 105, 110, 103, 95, 107, 101, 121, 42, 51, 10, 28, 105, 109, 112,
          111, 114, 116, 97, 110, 116, 95, 109, 101, 116, 97, 100, 97, 116, 97, 95, 99, 111, 110,
          110, 101, 99, 116, 101, 100, 18, 19, 116, 101, 115, 116, 95, 109, 101, 116, 97, 95, 99,
          111, 110, 110, 101, 99, 116, 101, 100>>

      assert AMQPTriggerTarget.encode(target) == serialized_target
      assert AMQPTriggerTarget.decode(serialized_target) == target
    end

    test "still works for DataTrigger" do
      alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger

      trigger = %DataTrigger{
        version: 1,
        interface_name: "com.test.SimpleStreamTest",
        interface_major: 1,
        data_trigger_type: :INCOMING_DATA,
        match_path: "/0/value",
        value_match_operator: :LESS_THAN,
        known_value: Cyanide.encode!(%{v: 100})
      }

      serialized_trigger =
        <<8, 1, 16, 1, 26, 25, 99, 111, 109, 46, 116, 101, 115, 116, 46, 83, 105, 109, 112, 108,
          101, 83, 116, 114, 101, 97, 109, 84, 101, 115, 116, 32, 1, 42, 8, 47, 48, 47, 118, 97,
          108, 117, 101, 48, 6, 58, 12, 12, 0, 0, 0, 16, 118, 0, 100, 0, 0, 0, 0>>

      assert DataTrigger.encode(trigger) == serialized_trigger
      assert DataTrigger.decode(serialized_trigger) == trigger
    end

    test "still works for DeviceTrigger" do
      alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger

      trigger = %DeviceTrigger{
        version: 1,
        device_id: "f0VMRgIBAQAAAAAAAAAAAA",
        device_event_type: :DEVICE_CONNECTED
      }

      serialized_trigger =
        <<8, 1, 16, 1, 26, 22, 102, 48, 86, 77, 82, 103, 73, 66, 65, 81, 65, 65, 65, 65, 65, 65,
          65, 65, 65, 65, 65, 65>>

      assert DeviceTrigger.encode(trigger) == serialized_trigger
      assert DeviceTrigger.decode(serialized_trigger) == trigger
    end

    test "still works for SimpleTriggerContainer" do
      alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger
      alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer

      container = %SimpleTriggerContainer{
        version: 1,
        simple_trigger: {
          :device_trigger,
          %DeviceTrigger{
            version: 1,
            device_event_type: :DEVICE_CONNECTED
          }
        }
      }

      serialized_container = <<8, 1, 18, 4, 8, 1, 16, 1>>

      assert SimpleTriggerContainer.encode(container) == serialized_container
      assert SimpleTriggerContainer.decode(serialized_container) == container
    end

    test "still works for TaggedSimpleTrigger" do
      alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger
      alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
      alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger

      trigger = %TaggedSimpleTrigger{
        version: 1,
        object_id: "9ac234b0-4767-449c-a581-345c2bafaece",
        object_type: 2,
        simple_trigger_container: %SimpleTriggerContainer{
          version: 1,
          simple_trigger: {
            :device_trigger,
            %DeviceTrigger{
              version: 1,
              device_event_type: :DEVICE_CONNECTED
            }
          }
        }
      }

      serialized_trigger =
        <<8, 1, 18, 36, 57, 97, 99, 50, 51, 52, 98, 48, 45, 52, 55, 54, 55, 45, 52, 52, 57, 99,
          45, 97, 53, 56, 49, 45, 51, 52, 53, 99, 50, 98, 97, 102, 97, 101, 99, 101, 24, 2, 34, 8,
          8, 1, 18, 4, 8, 1, 16, 1>>

      assert TaggedSimpleTrigger.encode(trigger) == serialized_trigger
      assert TaggedSimpleTrigger.decode(serialized_trigger) == trigger
    end

    test "still works for TriggerTargetContainer" do
      alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
      alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer

      simple_trigger_id = "c0cd4ff8-1ee1-4162-b654-2697f6af652b"
      parent_trigger_id = "825b42ff-6664-4f67-ac64-71a1865acb05"
      static_header_key = "important_metadata_connected"
      static_header_value = "test_meta_connected"
      static_headers = %{static_header_key => static_header_value}
      routing_key = "test_routing_key"

      trigger = %TriggerTargetContainer{
        version: 1,
        trigger_target: {
          :amqp_trigger_target,
          %AMQPTriggerTarget{
            version: 1,
            simple_trigger_id: simple_trigger_id,
            parent_trigger_id: parent_trigger_id,
            static_headers: static_headers,
            routing_key: routing_key
          }
        }
      }

      serialized_trigger =
        <<8, 1, 18, 149, 1, 8, 1, 18, 36, 99, 48, 99, 100, 52, 102, 102, 56, 45, 49, 101, 101, 49,
          45, 52, 49, 54, 50, 45, 98, 54, 53, 52, 45, 50, 54, 57, 55, 102, 54, 97, 102, 54, 53,
          50, 98, 26, 36, 56, 50, 53, 98, 52, 50, 102, 102, 45, 54, 54, 54, 52, 45, 52, 102, 54,
          55, 45, 97, 99, 54, 52, 45, 55, 49, 97, 49, 56, 54, 53, 97, 99, 98, 48, 53, 34, 16, 116,
          101, 115, 116, 95, 114, 111, 117, 116, 105, 110, 103, 95, 107, 101, 121, 42, 51, 10, 28,
          105, 109, 112, 111, 114, 116, 97, 110, 116, 95, 109, 101, 116, 97, 100, 97, 116, 97, 95,
          99, 111, 110, 110, 101, 99, 116, 101, 100, 18, 19, 116, 101, 115, 116, 95, 109, 101,
          116, 97, 95, 99, 111, 110, 110, 101, 99, 116, 101, 100>>

      assert TriggerTargetContainer.encode(trigger) == serialized_trigger
      assert TriggerTargetContainer.decode(serialized_trigger) == trigger
    end
  end
end
