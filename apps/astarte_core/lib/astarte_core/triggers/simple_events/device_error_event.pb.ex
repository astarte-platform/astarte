defmodule Astarte.Core.Triggers.SimpleEvents.DeviceErrorEvent.MetadataEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule Astarte.Core.Triggers.SimpleEvents.DeviceErrorEvent do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :error_name, 1, proto3_optional: true, type: :string, json_name: "errorName"

  field :metadata, 2,
    repeated: true,
    type: Astarte.Core.Triggers.SimpleEvents.DeviceErrorEvent.MetadataEntry,
    map: true
end
