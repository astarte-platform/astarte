defmodule Astarte.Core.Triggers.PolicyProtobuf.Handler.StrategyType do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :INVALID, 0
  field :DISCARD, 1
  field :RETRY, 2
end

defmodule Astarte.Core.Triggers.PolicyProtobuf.Handler do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  oneof :on, 0

  field :strategy, 1, type: Astarte.Core.Triggers.PolicyProtobuf.Handler.StrategyType, enum: true

  field :error_keyword, 2,
    type: Astarte.Core.Triggers.PolicyProtobuf.ErrorKeyword,
    json_name: "errorKeyword",
    oneof: 0

  field :error_range, 3,
    type: Astarte.Core.Triggers.PolicyProtobuf.ErrorRange,
    json_name: "errorRange",
    oneof: 0
end
