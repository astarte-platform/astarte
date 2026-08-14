defmodule Astarte.Core.Triggers.PolicyProtobuf.ErrorKeyword.KeywordType do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :INVALID, 0
  field :ANY_ERROR, 1
  field :CLIENT_ERROR, 2
  field :SERVER_ERROR, 3
end

defmodule Astarte.Core.Triggers.PolicyProtobuf.ErrorKeyword do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :keyword, 1,
    type: Astarte.Core.Triggers.PolicyProtobuf.ErrorKeyword.KeywordType,
    enum: true
end
