defmodule Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof :simple_trigger, 0

  field :version, 1, type: :int32, deprecated: true

  field :device_trigger, 2,
    type: Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger,
    json_name: "deviceTrigger",
    oneof: 0

  field :data_trigger, 3,
    type: Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger,
    json_name: "dataTrigger",
    oneof: 0
end
