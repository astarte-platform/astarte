defmodule Astarte.Core.Triggers.SimpleEvents.PathRemovedEvent do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :interface, 1, proto3_optional: true, type: :string
  field :path, 2, proto3_optional: true, type: :string
end
