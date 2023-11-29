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
    DeleteRealm,
    DoesRealmExist,
    DoesRealmExistReply,
    GenericErrorReply,
    GenericOkReply,
    GetRealm,
    GetRealmReply,
    GetRealmsList,
    GetRealmsListReply,
    Reply,
    UpdateRealm
  }

  alias Astarte.Housekeeping.RPC.Handler
  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Engine
  alias Astarte.Housekeeping.DatabaseTestHelper

  @invalid_test_realm "not~valid"
  @not_existing_realm "nonexistingrealm"
  @test_realm "newtestrealm"
  @replication_factor 1

  @public_key_pem "this_is_not_a_pem_but_it_will_do_for_tests"
  @device_limit 1

  setup_all do
    :ok = DatabaseTestHelper.wait_and_initialize()

    on_exit(fn ->
      DatabaseTestHelper.drop_astarte_keyspace()
    end)
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

  test "realm creation and DoesRealmExist successful call with implicit replication" do
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

    encoded =
      %Call{call: {:does_realm_exist, %DoesRealmExist{realm: @test_realm}}}
      |> Call.encode()

    expected = %Reply{
      error: false,
      reply: {:does_realm_exist_reply, %DoesRealmExistReply{exists: true}},
      version: 0
    }

    {:ok, exists_reply} = Handler.handle_rpc(encoded)

    assert Reply.decode(exists_reply) == expected
  end

  test "realm creation and GetRealm successful call with explicit SimpleStrategy replication" do
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

    encoded =
      %Call{call: {:get_realm, %GetRealm{realm_name: @test_realm}}}
      |> Call.encode()

    expected = %Reply{
      version: 0,
      error: false,
      reply:
        {:get_realm_reply,
         %GetRealmReply{
           realm_name: @test_realm,
           jwt_public_key_pem: @public_key_pem,
           replication_class: :SIMPLE_STRATEGY,
           replication_factor: @replication_factor
         }}
    }

    {:ok, exists_reply} = Handler.handle_rpc(encoded)

    assert Reply.decode(exists_reply) == expected
  end

  test "realm creation and GetRealm successful call with explicit NetworkTopologyStrategy replication" do
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

    encoded =
      %Call{call: {:get_realm, %GetRealm{realm_name: @test_realm}}}
      |> Call.encode()

    expected = %Reply{
      version: 0,
      error: false,
      reply:
        {:get_realm_reply,
         %GetRealmReply{
           realm_name: @test_realm,
           jwt_public_key_pem: @public_key_pem,
           replication_class: :NETWORK_TOPOLOGY_STRATEGY,
           datacenter_replication_factors: %{"datacenter1" => 1},
           replication_factor: 0
         }}
    }

    {:ok, exists_reply} = Handler.handle_rpc(encoded)

    assert Reply.decode(exists_reply) == expected
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

  test "DoesRealmExist non-existing realm" do
    encoded =
      %Call{call: {:does_realm_exist, %DoesRealmExist{realm: @not_existing_realm}}}
      |> Call.encode()

    expected = %Reply{
      version: 0,
      error: false,
      reply: {:does_realm_exist_reply, %DoesRealmExistReply{exists: false}}
    }

    {:ok, enc_reply} = Handler.handle_rpc(encoded)

    assert Reply.decode(enc_reply) == expected
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

  test "GetRealm successful call" do
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

    encoded =
      %Call{call: {:get_realm, %GetRealm{realm_name: @test_realm}}}
      |> Call.encode()

    {:ok, reply} = Handler.handle_rpc(encoded)

    expected = %Reply{
      version: 0,
      error: false,
      reply:
        {:get_realm_reply,
         %GetRealmReply{
           realm_name: @test_realm,
           jwt_public_key_pem: @public_key_pem,
           replication_class: :SIMPLE_STRATEGY,
           replication_factor: @replication_factor
         }}
    }

    assert Reply.decode(reply) == expected
  end

  test "GetRealm failed call" do
    encoded =
      %Call{call: {:get_realm, %GetRealm{realm_name: @not_existing_realm}}}
      |> Call.encode()

    {:ok, reply} = Handler.handle_rpc(encoded)

    expected = generic_error("realm_not_found")

    assert Reply.decode(reply) == expected
  end

  test "DeleteRealm successful call" do
    Engine.create_realm(@test_realm, @public_key_pem, @replication_factor, @device_limit)

    encoded =
      %Call{call: {:delete_realm, %DeleteRealm{realm: @test_realm}}}
      |> Call.encode()

    {:ok, reply} = Handler.handle_rpc(encoded)

    assert Reply.decode(reply) == generic_ok()
  end

  test "DeleteRealm with empty realm_name fails" do
    encoded =
      %Call{call: {:delete_realm, %DeleteRealm{realm: ""}}}
      |> Call.encode()

    {:ok, reply} = Handler.handle_rpc(encoded)

    assert Reply.decode(reply) == generic_error("empty_name", "empty realm name")
  end

  test "DeleteRealm with non-existing realm fails" do
    encoded =
      %Call{call: {:delete_realm, %DeleteRealm{realm: @not_existing_realm}}}
      |> Call.encode()

    {:ok, reply} = Handler.handle_rpc(encoded)

    assert Reply.decode(reply) == generic_error("realm_not_found")
  end

  test "DeleteRealm fails if realm deletion is disabled" do
    on_exit(fn ->
      DatabaseTestHelper.realm_cleanup(@test_realm)
      Config.reload_enable_realm_deletion()
    end)

    Engine.create_realm(@test_realm, @public_key_pem, @replication_factor, @device_limit)

    Config.put_enable_realm_deletion(false)

    encoded =
      %Call{call: {:delete_realm, %DeleteRealm{realm: @test_realm}}}
      |> Call.encode()

    {:ok, reply} = Handler.handle_rpc(encoded)

    assert Reply.decode(reply) == generic_error("realm_deletion_disabled")
  end

  describe "UpdateRealm" do
    setup do
      alias Astarte.Housekeeping.Queries

      :ok =
        Queries.create_realm(
          @test_realm,
          "test1publickey",
          @replication_factor,
          @device_limit,
          []
        )

      on_exit(fn ->
        DatabaseTestHelper.realm_cleanup(@test_realm)
      end)
    end

    test "succeeds when realm exists and update values are valid" do
      encoded =
        %Call{
          call:
            {:update_realm, %UpdateRealm{realm: @test_realm, jwt_public_key_pem: @public_key_pem}}
        }
        |> Call.encode()

      {:ok, update_reply} = Handler.handle_rpc(encoded)

      expected = %Reply{
        version: 0,
        error: false,
        reply:
          {:get_realm_reply,
           %GetRealmReply{
             realm_name: @test_realm,
             jwt_public_key_pem: @public_key_pem,
             replication_class: :SIMPLE_STRATEGY,
             replication_factor: @replication_factor,
             device_registration_limit: @device_limit
           }}
      }

      assert Reply.decode(update_reply) == expected
    end

    test "fails with error when realm does not exist" do
      encoded =
        %Call{
          call:
            {:update_realm,
             %UpdateRealm{realm: "i_dont_exist", jwt_public_key_pem: @public_key_pem}}
        }
        |> Call.encode()

      {:ok, update_reply} = Handler.handle_rpc(encoded)

      expected = %Reply{
        version: 0,
        error: true,
        reply:
          {:generic_error_reply,
           %GenericErrorReply{
             error_name: "realm_not_found"
           }}
      }

      assert Reply.decode(update_reply) == expected
    end

    test "fails with error when update parameters are invalid" do
      encoded =
        %Call{call: {:update_realm, %UpdateRealm{realm: @test_realm, replication_factor: 10}}}
        |> Call.encode()

      {:ok, update_reply} = Handler.handle_rpc(encoded)

      expected = %Reply{
        version: 0,
        error: true,
        reply:
          {:generic_error_reply,
           %GenericErrorReply{
             error_name: "invalid_update_parameters"
           }}
      }

      assert Reply.decode(update_reply) == expected
    end
  end
end
