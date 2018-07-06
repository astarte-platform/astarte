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
# Copyright (C) 2017-2018 Ispirata Srl
#

defmodule Astarte.Pairing.API.AgentTest do
  use Astarte.Pairing.API.DataCase

  alias Astarte.Pairing.API.Agent

  alias Astarte.RPC.Protocol.Pairing.{
    Call,
    GenericErrorReply,
    RegisterDevice,
    RegisterDeviceReply,
    Reply
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

    test "successful call" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination ->
        assert %Call{call: {:register_device, %RegisterDevice{} = register_call}} =
                 Call.decode(serialized_call)

        assert %RegisterDevice{
                 realm: @test_realm,
                 hw_id: @test_hw_id
               } = register_call

        {:ok, @encoded_register_response}
      end)

      assert {:ok, %DeviceRegistrationResponse{credentials_secret: @credentials_secret}} =
               Agent.register_device(@test_realm, @valid_attrs)
    end

    test "returns error changeset with invalid data" do
      assert {:error, %Ecto.Changeset{}} = Agent.register_device(@test_realm, @no_hw_id_attrs)

      assert {:error, %Ecto.Changeset{}} =
               Agent.register_device(@test_realm, @invalid_hw_id_attrs)
    end

    test "returns error if RPC returns error" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination ->
        assert %Call{call: {:register_device, %RegisterDevice{} = register_call}} =
                 Call.decode(serialized_call)

        assert %RegisterDevice{
                 realm: @test_realm,
                 hw_id: @already_registered_hw_id
               } = register_call

        {:ok, @encoded_error_response}
      end)

      assert {:error, %Ecto.Changeset{}} =
               Agent.register_device(@test_realm, %{"hw_id" => @already_registered_hw_id})
    end
  end
end
