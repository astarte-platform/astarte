defmodule Astarte.Housekeeping.AMQPServerTest do
  use ExUnit.Case
  alias Astarte.Housekeeping.RPC.AMQPServer
  use Astarte.RPC.Protocol.Housekeeping

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

  test "realm creation and DoesRealmExist successful call" do
    encoded = Call.new(call: {:create_realm, CreateRealm.new(realm: "newtestrealm")})
      |> Call.encode()

    assert AMQPServer.process_rpc(encoded) == :ok

    encoded = %Call{call: {:does_realm_exist, %DoesRealmExist{realm: "newtestrealm"}}}
      |> Call.encode()

    expected = %Reply{reply: {:does_realm_exist_reply, %DoesRealmExistReply{exists: true}}}

    {:ok, enc_reply} = AMQPServer.process_rpc(encoded)

    assert Reply.decode(enc_reply) == expected
  end

  test "DoesRealmExist non-existing realm" do
    encoded = %Call{call: {:does_realm_exist, %DoesRealmExist{realm: "nonexistingrealm"}}}
      |> Call.encode()

    expected = %Reply{reply: {:does_realm_exist_reply, %DoesRealmExistReply{exists: false}}}

    {:ok, enc_reply} = AMQPServer.process_rpc(encoded)

    assert Reply.decode(enc_reply) == expected
  end
end
