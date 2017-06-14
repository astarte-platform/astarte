defmodule Housekeeping.RPC do
  @external_resource Path.expand("proto/housekeeping_rpc.proto")

  use Protobuf, from: Path.expand("proto/housekeeping_rpc.proto")
end
