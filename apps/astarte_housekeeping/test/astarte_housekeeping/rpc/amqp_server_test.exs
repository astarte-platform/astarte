#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.Housekeeping.RPC.HandlerTest do
  use ExUnit.Case

  alias Astarte.RPC.Protocol.Housekeeping.{
    Call,
    CreateRealm,
    GenericErrorReply,
    GenericOkReply,
    GetRealmReply,
    GetRealmsList,
    GetRealmsListReply,
    Reply
  }

  alias Astarte.Housekeeping.RPC.Handler
  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Engine
  alias Astarte.Housekeeping.DatabaseTestHelper
  alias Astarte.Housekeeping.Helpers.Database

  alias Astarte.Housekeeping.Queries

  @invalid_test_realm "not~valid"
  @not_existing_realm "nonexistingrealm"
  @test_realm "newtestrealm"
  @replication_factor 1

  @public_key_pem "this_is_not_a_pem_but_it_will_do_for_tests"
  @device_limit 1
  @datastream_maximum_storage_retention 1

  setup do
    on_exit(fn ->
      Database.destroy_test_astarte_keyspace!(:xandra)
    end)

    Queries.initialize_database()
  end

  defp generic_error(
         error_name,
         user_readable_message \\ nil,
         user_readable_error_name \\ nil,
         error_data \\ nil
       ) do
    %Reply{
      version: 0,
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
    %Reply{
      version: 0,
      error: false,
      reply: {:generic_ok_reply, %GenericOkReply{async_operation: async}}
    }
  end

  test "invalid empty message" do
    encoded =
      Call.new()
      |> Call.encode()

    assert Handler.handle_rpc(encoded) == {:error, :empty_call}
  end

  test "CreateRealm call with nil realm" do
    encoded =
      Call.new(call: {:create_realm, CreateRealm.new()})
      |> Call.encode()

    expected = generic_error("empty_name", "empty realm name")

    {:ok, reply} = Handler.handle_rpc(encoded)

    assert Reply.decode(reply) == expected
  end

  test "CreateRealm call with nil public key" do
    encoded =
      Call.new(call: {:create_realm, CreateRealm.new(realm: @test_realm)})
      |> Call.encode()

    expected = generic_error("empty_public_key", "empty jwt public key pem")

    {:ok, reply} = Handler.handle_rpc(encoded)

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

    {:ok, reply} = Handler.handle_rpc(encoded)

    assert Reply.decode(reply) == generic_error("realm_not_allowed")
  end

  test "realm creation successful call with implicit replication" do
    on_exit(fn ->
      DatabaseTestHelper.realm_cleanup(@test_realm)
    end)

    encoded =
      Call.new(
        call:
          {:create_realm,
           CreateRealm.new(realm: @test_realm, jwt_public_key_pem: @public_key_pem)}
      )
      |> Call.encode()

    {:ok, create_reply} = Handler.handle_rpc(encoded)

    assert Reply.decode(create_reply) == generic_ok()
  end

  test "Realm creation succeeds when device_registration_limit is not set" do
    on_exit(fn ->
      DatabaseTestHelper.realm_cleanup(@test_realm)
    end)

    encoded =
      %Call{
        call:
          {:create_realm,
           %CreateRealm{
             realm: @test_realm,
             jwt_public_key_pem: @public_key_pem,
             device_registration_limit: nil
           }}
      }
      |> Call.encode()

    {:ok, create_reply} = Handler.handle_rpc(encoded)

    assert Reply.decode(create_reply) == generic_ok()
  end

  test "realm creation successful call with explicit SimpleStrategy replication" do
    on_exit(fn ->
      DatabaseTestHelper.realm_cleanup(@test_realm)
    end)

    encoded =
      Call.new(
        call:
          {:create_realm,
           CreateRealm.new(
             realm: @test_realm,
             jwt_public_key_pem: @public_key_pem,
             replication_factor: @replication_factor
           )}
      )
      |> Call.encode()

    {:ok, create_reply} = Handler.handle_rpc(encoded)

    assert Reply.decode(create_reply) == generic_ok()
  end

  test "realm creation successful call with explicit NetworkTopologyStrategy replication" do
    on_exit(fn ->
      DatabaseTestHelper.realm_cleanup(@test_realm)
    end)

    encoded =
      Call.new(
        call:
          {:create_realm,
           CreateRealm.new(
             realm: @test_realm,
             jwt_public_key_pem: @public_key_pem,
             replication_class: :NETWORK_TOPOLOGY_STRATEGY,
             datacenter_replication_factors: %{"datacenter1" => 1}
           )}
      )
      |> Call.encode()

    {:ok, create_reply} = Handler.handle_rpc(encoded)

    assert Reply.decode(create_reply) == generic_ok()
  end

  test "realm creation fails with invalid SimpleStrategy replication" do
    encoded =
      Call.new(
        call:
          {:create_realm,
           CreateRealm.new(
             realm: @test_realm,
             jwt_public_key_pem: @public_key_pem,
             replication_factor: 9
           )}
      )
      |> Call.encode()

    {:ok, create_reply} = Handler.handle_rpc(encoded)

    assert %Reply{
             error: true,
             reply: {:generic_error_reply, %GenericErrorReply{error_name: "invalid_replication"}}
           } = Reply.decode(create_reply)
  end

  test "realm creation fails with invalid NetworkTopologyStrategy replication" do
    encoded =
      Call.new(
        call:
          {:create_realm,
           CreateRealm.new(
             realm: @test_realm,
             jwt_public_key_pem: @public_key_pem,
             replication_class: :NETWORK_TOPOLOGY_STRATEGY,
             datacenter_replication_factors: [{"imaginarydatacenter", 3}]
           )}
      )
      |> Call.encode()

    {:ok, create_reply} = Handler.handle_rpc(encoded)

    assert %Reply{
             error: true,
             reply: {:generic_error_reply, %GenericErrorReply{error_name: "invalid_replication"}}
           } = Reply.decode(create_reply)
  end

  test "GetRealmsList successful call" do
    encoded =
      %Call{call: {:get_realms_list, %GetRealmsList{}}}
      |> Call.encode()

    {:ok, list_reply} = Handler.handle_rpc(encoded)

    assert match?(
             %Reply{reply: {:get_realms_list_reply, %GetRealmsListReply{realms_names: _names}}},
             Reply.decode(list_reply)
           )
  end
end
