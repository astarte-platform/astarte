defmodule Astarte.Core.Triggers.SimpleTriggersProtobuf.UtilsTest do
  use ExUnit.Case

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger, as: ProtoDataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils

  test "get_interface_id_or_any/2 returns :any_interface for wildcard, id otherwise" do
    assert Utils.get_interface_id_or_any("*", 0) == :any_interface
    id = CQLUtils.interface_id("com.Test", 1)
    assert Utils.get_interface_id_or_any("com.Test", 1) == id
  end

  test "deserialize_simple_trigger/1 roundtrips a data trigger" do
    trigger = %ProtoDataTrigger{
      interface_name: "com.Test",
      interface_major: 1,
      data_trigger_type: :INCOMING_DATA,
      match_path: "/value",
      value_match_operator: :ANY
    }

    container = %SimpleTriggerContainer{simple_trigger: {:data_trigger, trigger}}
    payload = SimpleTriggerContainer.encode(container)
    assert {:data_trigger, ^trigger} = Utils.deserialize_simple_trigger(payload)
  end

  test "deserialize_trigger_target/1 roundtrips an AMQP target" do
    target = %AMQPTriggerTarget{
      routing_key: "test.key",
      simple_trigger_id: "abc",
      parent_trigger_id: "def"
    }

    container = %TriggerTargetContainer{trigger_target: {:amqp_trigger_target, target}}
    payload = TriggerTargetContainer.encode(container)
    assert ^target = Utils.deserialize_trigger_target(payload)
  end

  test "simple_trigger_to_data_trigger/1 converts with known_value" do
    encoded = Cyanide.encode!(%{v: 42})

    proto_trigger = %ProtoDataTrigger{
      interface_name: "com.Test",
      interface_major: 1,
      data_trigger_type: :INCOMING_DATA,
      match_path: "/value",
      value_match_operator: :EQUAL_TO,
      known_value: encoded
    }

    result = Utils.simple_trigger_to_data_trigger(proto_trigger)
    assert result.known_value == 42
    assert result.path_match_tokens == ["value"]
  end

  test "simple_trigger_to_data_trigger/1 handles wildcard match_path and INVALID_OPERATOR" do
    proto_trigger = %ProtoDataTrigger{
      interface_name: "*",
      interface_major: 0,
      data_trigger_type: :INCOMING_DATA,
      match_path: "/*",
      value_match_operator: :INVALID_OPERATOR,
      known_value: nil
    }

    result = Utils.simple_trigger_to_data_trigger(proto_trigger)
    assert result.path_match_tokens == :any_endpoint
    assert result.value_match_operator == :ANY
    assert result.interface_id == :any_interface
  end
end
