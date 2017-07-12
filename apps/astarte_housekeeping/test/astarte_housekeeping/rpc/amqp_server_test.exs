defmodule Astarte.Housekeeping.AMQPServerTest do
  use ExUnit.Case
  alias Astarte.Housekeeping.RPC.AMQPServer
  alias Astarte.RPC.Protocol.Housekeeping.{Call,CreateRealm}

  test "invalid empty message" do
    encoded = Call.new
      |> Call.encode
    assert AMQPServer.process_rpc(encoded) == {:error, :empty_call}
  end

  test "CreateRealm call with nil realm" do

    encoded = Call.new(call: {:create_realm, CreateRealm.new})
      |> Call.encode()

    assert AMQPServer.process_rpc(encoded) == {:error, :invalid_argument}
  end

  test "valid call, invalid realm_name" do

    encoded = Call.new(call: {:create_realm, CreateRealm.new(realm: "not~valid")})
      |> Call.encode()

    assert AMQPServer.process_rpc(encoded) == {:error, :realm_not_allowed}
  end
end
