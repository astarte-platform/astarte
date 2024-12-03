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

defmodule Astarte.Pairing.API.InfoTest do
  use Astarte.Pairing.API.DataCase

  alias Astarte.Pairing.API.Info.DeviceInfo
  alias Astarte.Pairing.API.Info

  alias Astarte.RPC.Protocol.Pairing.{
    AstarteMQTTV1Status,
    Call,
    GenericErrorReply,
    GetInfo,
    GetInfoReply,
    ProtocolStatus,
    Reply
  }

  import Mox

  @test_realm "testrealm"
  @test_hw_id "PDL3KNj7RVifHZD-1w_6wA"

  @credentials_secret "7wfs9MIBysBGG/v6apqNVBXXQii6Bris6CeU7FdCgWU="
  @wrong_credentials_secret "8wfs9MIBysBGG/v6apqNVBXXQii6Bris6CeU7FdCgWU="
  @version "0.1.0"
  @status "confirmed"
  @broker_url "ssl://broker.example.com:8883"

  @encoded_info_response %Reply{
                           reply:
                             {:get_info_reply,
                              %GetInfoReply{
                                version: @version,
                                device_status: @status,
                                protocols: [
                                  %ProtocolStatus{
                                    status:
                                      {:astarte_mqtt_v1,
                                       %AstarteMQTTV1Status{broker_url: @broker_url}}
                                  }
                                ]
                              }}
                         }
                         |> Reply.encode()
  @encoded_forbidden_response %Reply{
                                reply:
                                  {:generic_error_reply,
                                   %GenericErrorReply{error_name: "forbidden"}}
                              }
                              |> Reply.encode()

  @rpc_destination Astarte.RPC.Protocol.Pairing.amqp_queue()
  @timeout 30_000

  describe "device_info" do
    test "returns valid info with authorized call" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:get_info, %GetInfo{} = get_info_call}} = Call.decode(serialized_call)

        assert %GetInfo{
                 realm: @test_realm,
                 hw_id: @test_hw_id,
                 secret: @credentials_secret
               } = get_info_call

        {:ok, @encoded_info_response}
      end)

      assert {:ok, %DeviceInfo{status: @status, version: @version, protocols: protocols}} =
               Info.get_device_info(@test_realm, @test_hw_id, @credentials_secret)

      assert %{astarte_mqtt_v1: %{broker_url: @broker_url}} = protocols
    end

    test "returns forbidden with forbidden call" do
      MockRPCClient
      |> expect(:rpc_call, fn _serialized_call, @rpc_destination, @timeout ->
        {:ok, @encoded_forbidden_response}
      end)

      assert {:error, :forbidden} =
               Info.get_device_info(@test_realm, @test_hw_id, @wrong_credentials_secret)
    end
  end
end
