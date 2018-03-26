#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.Housekeeping.AMQPServerTest do
  use ExUnit.Case
  alias Astarte.Housekeeping.RPC.AMQPServer
  use Astarte.RPC.Protocol.Housekeeping

  @invalid_test_realm "not~valid"
  @not_existing_realm "nonexistingrealm"
  @test_realm "newtestrealm"
  @another_test_realm "anothertestrealm"

  @public_key_pem "this_is_not_a_pem_but_it_will_do_for_tests"

  defp generic_error(
         error_name,
         user_readable_message \\ nil,
         user_readable_error_name \\ nil,
         error_data \\ nil
       ) do
    %Reply{
      reply:
        {:generic_error_reply,
         %GenericErrorReply{
           error_name: error_name,
           user_readable_message: user_readable_message,
           user_readable_error_name: user_readable_error_name,
           error_data: error_data
         }},
      error: true
    }
  end

  defp generic_ok(async \\ false) do
    %Reply{reply: {:generic_ok_reply, %GenericOkReply{async_operation: async}}}
  end

  test "invalid empty message" do
    encoded =
      Call.new()
      |> Call.encode()

    assert AMQPServer.process_rpc(encoded) == {:error, :empty_call}
  end

  test "CreateRealm call with nil realm" do
    encoded =
      Call.new(call: {:create_realm, CreateRealm.new()})
      |> Call.encode()

    expected = generic_error("empty_name", "empty realm name")

    {:ok, reply} = AMQPServer.process_rpc(encoded)

    assert Reply.decode(reply) == generic_error("empty_name", "empty realm name")
  end

  test "CreateRealm call with nil public key" do
    encoded =
      Call.new(call: {:create_realm, CreateRealm.new(realm: @test_realm)})
      |> Call.encode()

    expected = generic_error("empty_public_key", "empty jwt public key pem")

    {:ok, reply} = AMQPServer.process_rpc(encoded)

    assert Reply.decode(reply) == expected
  end

  test "valid call, invalid realm_name" do
    encoded =
      Call.new(
        call:
          {:create_realm,
           CreateRealm.new(realm: @invalid_test_realm, jwt_public_key_pem: @public_key_pem)}
      )
      |> Call.encode()

    {:ok, reply} = AMQPServer.process_rpc(encoded)

    assert Reply.decode(reply) == generic_error("realm_not_allowed")
  end

  test "realm creation and DoesRealmExist successful call" do
    encoded =
      Call.new(
        call:
          {:create_realm,
           CreateRealm.new(realm: @test_realm, jwt_public_key_pem: @public_key_pem)}
      )
      |> Call.encode()

    {:ok, create_reply} = AMQPServer.process_rpc(encoded)

    assert Reply.decode(create_reply) == generic_ok()

    encoded =
      %Call{call: {:does_realm_exist, %DoesRealmExist{realm: @test_realm}}}
      |> Call.encode()

    expected = %Reply{reply: {:does_realm_exist_reply, %DoesRealmExistReply{exists: true}}}

    {:ok, exists_reply} = AMQPServer.process_rpc(encoded)

    assert Reply.decode(exists_reply) == expected
  end

  test "DoesRealmExist non-existing realm" do
    encoded =
      %Call{call: {:does_realm_exist, %DoesRealmExist{realm: @not_existing_realm}}}
      |> Call.encode()

    expected = %Reply{reply: {:does_realm_exist_reply, %DoesRealmExistReply{exists: false}}}

    {:ok, enc_reply} = AMQPServer.process_rpc(encoded)

    assert Reply.decode(enc_reply) == expected
  end

  test "GetRealmsList successful call" do
    encoded =
      %Call{call: {:get_realms_list, %GetRealmsList{}}}
      |> Call.encode()

    {:ok, list_reply} = AMQPServer.process_rpc(encoded)

    assert match?(
             %Reply{reply: {:get_realms_list_reply, %GetRealmsListReply{realms_names: names}}},
             Reply.decode(list_reply)
           )
  end

  test "GetRealm successful call" do
    # We create another realm to avoid test ordering problems
    encoded =
      Call.new(
        call:
          {:create_realm,
           CreateRealm.new(realm: @another_test_realm, jwt_public_key_pem: @public_key_pem)}
      )
      |> Call.encode()

    {:ok, create_reply} = AMQPServer.process_rpc(encoded)

    assert Reply.decode(create_reply) == generic_ok()

    encoded =
      %Call{call: {:get_realm, %GetRealm{realm_name: @another_test_realm}}}
      |> Call.encode()

    {:ok, reply} = AMQPServer.process_rpc(encoded)

    expected = %Reply{
      reply:
        {:get_realm_reply,
         %GetRealmReply{realm_name: @another_test_realm, jwt_public_key_pem: @public_key_pem}}
    }

    assert Reply.decode(reply) == expected
  end

  test "GetRealm failed call" do
    encoded =
      %Call{call: {:get_realm, %GetRealm{realm_name: @not_existing_realm}}}
      |> Call.encode()

    {:ok, reply} = AMQPServer.process_rpc(encoded)

    expected = generic_error("realm_not_found")

    assert Reply.decode(reply) == expected
  end
end
