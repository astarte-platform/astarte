#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.API.HealthTest do
  use Astarte.Pairing.API.DataCase

  alias Astarte.Pairing.API.Health
  alias Astarte.Pairing.API.Health.BackendHealth
  alias Astarte.RPC.Protocol.Pairing.Call
  alias Astarte.RPC.Protocol.Pairing.GetHealth
  alias Astarte.RPC.Protocol.Pairing.GetHealthReply
  alias Astarte.RPC.Protocol.Pairing.Reply

  import Mox

  defp encoded_health_response(status) do
    %Reply{
      reply:
        {:get_health_reply,
         %GetHealthReply{
           status: status
         }}
    }
    |> Reply.encode()
  end

  @rpc_destination Astarte.RPC.Protocol.Pairing.amqp_queue()
  @timeout 30_000

  describe "health" do
    test "returns :ready when RealmManagement replies with ready status" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:get_health, %GetHealth{}}} = Call.decode(serialized_call)

        {:ok, encoded_health_response(:READY)}
      end)

      assert {:ok, %BackendHealth{status: :ready}} = Health.get_backend_health()
    end

    test "returns :bad when RealmManagement replies with bad status" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:get_health, %GetHealth{}}} = Call.decode(serialized_call)

        {:ok, encoded_health_response(:BAD)}
      end)

      assert {:ok, %BackendHealth{status: :bad}} = Health.get_backend_health()
    end

    test "returns :degraded when RealmManagement replies with degraded status" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:get_health, %GetHealth{}}} = Call.decode(serialized_call)

        {:ok, encoded_health_response(:DEGRADED)}
      end)

      assert {:ok, %BackendHealth{status: :degraded}} = Health.get_backend_health()
    end

    test "returns :error when get_health returns an unexpected status" do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:get_health, %GetHealth{}}} = Call.decode(serialized_call)

        {:ok, encoded_health_response(:ERROR)}
      end)

      assert {:ok, %BackendHealth{status: :error}} = Health.get_backend_health()
    end
  end
end
