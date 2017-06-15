defmodule Housekeeping.RPC do
  @external_resource Path.expand("../proto/", __DIR__)

  use Protobuf, from: Path.wildcard(Path.expand("../proto/*.proto", __DIR__))
end
