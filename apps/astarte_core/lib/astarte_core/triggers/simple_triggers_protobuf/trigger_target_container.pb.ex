defmodule Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof :trigger_target, 0

  field :version, 1, type: :int32, deprecated: true

  field :amqp_trigger_target, 2,
    type: Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget,
    json_name: "amqpTriggerTarget",
    oneof: 0
end
