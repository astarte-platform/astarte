defmodule Astarte.Housekeeping.AMQPServerTest do
  use ExUnit.Case
  alias Astarte.Housekeeping.RPC.AMQPServer
  use Astarte.RPC.Protocol.Housekeeping

  @invalid_test_realm "not~valid"
  @not_existing_realm "nonexistingrealm"
  @test_realm "newtestrealm"

  defp generic_error(error_name, user_readable_message \\ nil, user_readable_error_name \\ nil, error_data \\ nil) do
    %Reply{reply: {:generic_error_reply, %GenericErrorReply{error_name: error_name,
                                                            user_readable_message: user_readable_message,
                                                            user_readable_error_name: user_readable_error_name,
                                                            error_data: error_data
                                                           }}}
  end

  defp generic_ok(async \\ false) do
    %Reply{reply: {:generic_ok_reply, %GenericOkReply{async_operation: async}}}
  end

  test "invalid empty message" do
    encoded = Call.new
      |> Call.encode
    assert AMQPServer.process_rpc(encoded) == {:error, :empty_call}
  end

  test "CreateRealm call with nil realm" do

    encoded = Call.new(call: {:create_realm, CreateRealm.new})
      |> Call.encode()

    expected = %Reply{reply: {:generic_error_reply, %GenericErrorReply{error_name: "empty_name",
                                                                       user_readable_message: "empty realm name"}}}
    {:ok, reply} = AMQPServer.process_rpc(encoded)

    assert Reply.decode(reply) == generic_error("empty_name", "empty realm name")
  end

  test "valid call, invalid realm_name" do

    encoded = Call.new(call: {:create_realm, CreateRealm.new(realm: @invalid_test_realm)})
      |> Call.encode()

    {:ok, reply} = AMQPServer.process_rpc(encoded)

    assert Reply.decode(reply) == generic_error("realm_not_allowed")
  end

  test "realm creation and DoesRealmExist successful call" do
    encoded = Call.new(call: {:create_realm, CreateRealm.new(realm: @test_realm)})
      |> Call.encode()

    {:ok, create_reply} = AMQPServer.process_rpc(encoded)

    assert Reply.decode(create_reply) == generic_ok()

    encoded = %Call{call: {:does_realm_exist, %DoesRealmExist{realm: @test_realm}}}
      |> Call.encode()

    expected = %Reply{reply: {:does_realm_exist_reply, %DoesRealmExistReply{exists: true}}}

    {:ok, exists_reply} = AMQPServer.process_rpc(encoded)

    assert Reply.decode(exists_reply) == expected
  end

  test "DoesRealmExist non-existing realm" do
    encoded = %Call{call: {:does_realm_exist, %DoesRealmExist{realm: @not_existing_realm}}}
      |> Call.encode()

    expected = %Reply{reply: {:does_realm_exist_reply, %DoesRealmExistReply{exists: false}}}

    {:ok, enc_reply} = AMQPServer.process_rpc(encoded)

    assert Reply.decode(enc_reply) == expected
  end

  test "GetRealmsList successful call" do
    encoded = %Call{call: {:get_realms_list, %GetRealmsList{}}}
      |> Call.encode()

    {:ok, list_reply} = AMQPServer.process_rpc(encoded)

    expected = %Reply{reply: {:get_realms_list_reply, %GetRealmsListReply{realms_names: [@test_realm]}}}

    assert Reply.decode(list_reply) == expected
  end

end
