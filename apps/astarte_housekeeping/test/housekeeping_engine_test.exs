defmodule HousekeepingEngineTest do
  use ExUnit.Case
  doctest HousekeepingEngine

  test "Protobuf RPC round trip" do
    create_realm_call = Housekeeping.RPC.CreateRealm.new(realm: "testRealm")
    reply_header = Housekeeping.RPC.ReplyHeader.new(call_id: 42, reply_exchange: "testExchange")
    type = :CREATE_REALM
    version = 42
    rpc = Housekeeping.RPC.Call.new(call: {:create_realm, create_realm_call},
                                    reply_header: reply_header,
                                    type: type,
                                    version: version)
    encoded = Housekeeping.RPC.Call.encode(rpc)
    decoded = Housekeeping.RPC.Call.decode(encoded)
    %Housekeeping.RPC.Call{call: {:create_realm, matched_call},
                           reply_header: matched_reply_header,
                           type: matched_type,
                           version: matched_version} = decoded
    assert(matched_call == create_realm_call)
    assert(matched_reply_header == reply_header)
    assert(matched_type == type)
    assert(matched_version == version)
  end
end
