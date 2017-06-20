defmodule HousekeepingRPCTest do
  use ExUnit.Case

  test "Protobuf RPC round trip" do
    create_realm_call = Housekeeping.RPC.CreateRealm.new(realm: "testRealm")
    reply_header = Housekeeping.RPC.ReplyHeader.new(call_id: 42, reply_exchange: "testExchange")
    version = 42
    rpc = Housekeeping.RPC.Call.new(call: {:create_realm, create_realm_call},
                                    reply_header: reply_header,
                                    version: version)
    encoded = Housekeeping.RPC.Call.encode(rpc)
    decoded = Housekeeping.RPC.Call.decode(encoded)
    %Housekeeping.RPC.Call{call: {:create_realm, matched_call},
                           reply_header: matched_reply_header,
                           version: matched_version} = decoded
    assert(matched_call == create_realm_call)
    assert(matched_reply_header == reply_header)
    assert(matched_version == version)
  end

  test "that we know when to reply" do
    create_realm_call = Housekeeping.RPC.CreateRealm.new(realm: "testRealm")
    version = 42
    rpc = Housekeeping.RPC.Call.new(call: {:create_realm, create_realm_call},
                                    version: version)

    willReply = case rpc do
      %Housekeeping.RPC.Call{reply_header: nil} -> false
      _ -> true
    end
    assert(willReply == false)
  end
end
