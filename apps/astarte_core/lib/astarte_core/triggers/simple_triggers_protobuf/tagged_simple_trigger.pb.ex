defmodule Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :version, 1, type: :int32, deprecated: true
  field :object_id, 2, proto3_optional: true, type: :bytes, json_name: "objectId"
  field :object_type, 3, type: :int32, json_name: "objectType"

  field :simple_trigger_container, 4,
    type: Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer,
    json_name: "simpleTriggerContainer"
end
