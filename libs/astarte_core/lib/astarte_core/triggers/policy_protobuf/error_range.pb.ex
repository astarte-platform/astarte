defmodule Astarte.Core.Triggers.PolicyProtobuf.ErrorRange do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :error_codes, 1, repeated: true, type: :int32, json_name: "errorCodes"
end
