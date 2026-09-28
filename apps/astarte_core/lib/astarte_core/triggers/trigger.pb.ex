defmodule Astarte.Core.Triggers.Trigger do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :version, 1, type: :int32, deprecated: true
  field :trigger_uuid, 2, proto3_optional: true, type: :bytes, json_name: "triggerUuid"
  field :simple_triggers_uuids, 3, repeated: true, type: :bytes, json_name: "simpleTriggersUuids"
  field :action, 4, proto3_optional: true, type: :bytes
  field :name, 5, proto3_optional: true, type: :string
  field :policy, 6, proto3_optional: true, type: :string
end
