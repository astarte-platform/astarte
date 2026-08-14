defmodule Astarte.Core.Triggers.SimpleEvents.ValueChangeAppliedEvent do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :interface, 1, proto3_optional: true, type: :string
  field :path, 2, proto3_optional: true, type: :string
  field :old_bson_value, 3, proto3_optional: true, type: :bytes, json_name: "oldBsonValue"
  field :new_bson_value, 4, proto3_optional: true, type: :bytes, json_name: "newBsonValue"
end
