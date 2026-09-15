defmodule Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget.StaticHeadersEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :version, 1, type: :int32, deprecated: true
  field :simple_trigger_id, 2, proto3_optional: true, type: :bytes, json_name: "simpleTriggerId"
  field :parent_trigger_id, 3, proto3_optional: true, type: :bytes, json_name: "parentTriggerId"
  field :routing_key, 4, proto3_optional: true, type: :string, json_name: "routingKey"

  field :static_headers, 5,
    repeated: true,
    type: Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget.StaticHeadersEntry,
    json_name: "staticHeaders",
    map: true

  field :exchange, 6, proto3_optional: true, type: :string
  field :message_expiration_ms, 7, type: :int32, json_name: "messageExpirationMs"
  field :message_priority, 8, type: :int32, json_name: "messagePriority"
  field :message_persistent, 9, type: :bool, json_name: "messagePersistent"
end
