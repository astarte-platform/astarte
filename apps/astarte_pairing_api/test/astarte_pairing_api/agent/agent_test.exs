# Copyright 2017-2019 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule Astarte.Pairing.API.AgentTest do
  use Astarte.Pairing.API.DataCase

  alias Astarte.Pairing.API.Agent

  alias Astarte.RPC.Protocol.Pairing.{
    Call,
    GenericErrorReply,
    GenericOkReply,
    IntrospectionEntry,
    RegisterDevice,
    RegisterDeviceReply,
    Reply,
    UnregisterDevice
  }

  import Mox

  describe "register_device" do
    alias Astarte.Pairing.API.Agent.DeviceRegistrationResponse

    @test_realm "testrealm"
    @test_hw_id "PDL3KNj7RVifHZD-1w_6wA"
    @already_registered_hw_id "PY3wK1OKQ3qKyQMBxi6S5w"

    @credentials_secret "7wfs9MIBysBGG/v6apqNVBXXQii6Bris6CeU7FdCgWU="
    @encoded_register_response %Reply{
                                 reply:
                                   {:register_device_reply,
                                    %RegisterDeviceReply{credentials_secret: @credentials_secret}}
                               }
                               |> Reply.encode()
    @encoded_error_response %Reply{
                              reply:
                                {:generic_error_reply,
                                 %GenericErrorReply{error_name: "already_registered"}}
                            }
                            |> Reply.encode()

    @valid_attrs %{"hw_id" => @test_hw_id}
    @no_hw_id_attrs %{}
    @invalid_hw_id_attrs %{"hw_id" => "invalid"}

    @rpc_destination Astarte.RPC.Protocol.Pairing.amqp_queue()
    @timeout 30_000

    test "successful call" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:register_device, %RegisterDevice{} = register_call}} =
                 Call.decode(serialized_call)

        assert %RegisterDevice{
                 realm: @test_realm,
                 hw_id: @test_hw_id,
                 initial_introspection: []
               } = register_call

        {:ok, @encoded_register_response}
      end)

      assert {:ok, %DeviceRegistrationResponse{credentials_secret: @credentials_secret}} =
               Agent.register_device(@test_realm, @valid_attrs)
    end

    test "succesful call with initial_introspection" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:register_device, register_device}} = Call.decode(serialized_call)

        assert Enum.member?(
                 register_device.initial_introspection,
                 %IntrospectionEntry{
                   interface_name: "org.astarteplatform.Values",
                   major_version: 0,
                   minor_version: 4
                 }
               )

        assert Enum.member?(
                 register_device.initial_introspection,
                 %IntrospectionEntry{
                   interface_name: "org.astarteplatform.OtherValues",
                   major_version: 1,
                   minor_version: 0
                 }
               )

        {:ok, @encoded_register_response}
      end)

      initial_introspection = %{
        "org.astarteplatform.Values" => %{"major" => 0, "minor" => 4},
        "org.astarteplatform.OtherValues" => %{"major" => 1, "minor" => 0}
      }

      attrs = Map.put(@valid_attrs, "initial_introspection", initial_introspection)

      assert {:ok, %DeviceRegistrationResponse{credentials_secret: @credentials_secret}} =
               Agent.register_device(@test_realm, attrs)
    end

    test "returns error changeset with invalid data" do
      assert {:error, %Ecto.Changeset{}} = Agent.register_device(@test_realm, @no_hw_id_attrs)

      assert {:error, %Ecto.Changeset{}} =
               Agent.register_device(@test_realm, @invalid_hw_id_attrs)
    end

    test "returns error if RPC returns error" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:register_device, %RegisterDevice{} = register_call}} =
                 Call.decode(serialized_call)

        assert %RegisterDevice{
                 realm: @test_realm,
                 hw_id: @already_registered_hw_id,
                 initial_introspection: []
               } = register_call

        {:ok, @encoded_error_response}
      end)

      assert {:error, %Ecto.Changeset{}} =
               Agent.register_device(@test_realm, %{"hw_id" => @already_registered_hw_id})
    end
  end

  describe "unregister device" do
    setup [:verify_on_exit!]

    @test_realm "testrealm"
    @test_device_id "PDL3KNj7RVifHZD-1w_6wA"
    @already_registered_hw_id "PY3wK1OKQ3qKyQMBxi6S5w"

    @credentials_secret "7wfs9MIBysBGG/v6apqNVBXXQii6Bris6CeU7FdCgWU="
    @encoded_unregister_response %Reply{
                                   reply: {:generic_ok_reply, %GenericOkReply{}}
                                 }
                                 |> Reply.encode()
    @encoded_device_not_registered_response %Reply{
                                              reply:
                                                {:generic_error_reply,
                                                 %GenericErrorReply{
                                                   error_name: "device_not_registered"
                                                 }}
                                            }
                                            |> Reply.encode()
    @encoded_realm_not_found_response %Reply{
                                        reply:
                                          {:generic_error_reply,
                                           %GenericErrorReply{
                                             error_name: "realm_not_found"
                                           }}
                                      }
                                      |> Reply.encode()

    @rpc_destination Astarte.RPC.Protocol.Pairing.amqp_queue()
    @timeout 30_000

    test "successful call" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:unregister_device, %UnregisterDevice{} = unregister_call}} =
                 Call.decode(serialized_call)

        assert %UnregisterDevice{
                 realm: @test_realm,
                 device_id: @test_device_id
               } = unregister_call

        {:ok, @encoded_unregister_response}
      end)

      assert :ok = Agent.unregister_device(@test_realm, @test_device_id)
    end

    test "unregistered device" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:unregister_device, %UnregisterDevice{} = unregister_call}} =
                 Call.decode(serialized_call)

        assert %UnregisterDevice{
                 realm: @test_realm,
                 device_id: @test_device_id
               } = unregister_call

        {:ok, @encoded_device_not_registered_response}
      end)

      assert {:error, :device_not_found} = Agent.unregister_device(@test_realm, @test_device_id)
    end

    test "realm not found" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:unregister_device, %UnregisterDevice{} = unregister_call}} =
                 Call.decode(serialized_call)

        assert %UnregisterDevice{
                 realm: @test_realm,
                 device_id: @test_device_id
               } = unregister_call

        {:ok, @encoded_realm_not_found_response}
      end)

      assert {:error, :forbidden} = Agent.unregister_device(@test_realm, @test_device_id)
    end

    test "invalid device id" do
      assert {:error, :invalid_device_id} = Agent.unregister_device(@test_realm, "invalid")
    end
  end
end
