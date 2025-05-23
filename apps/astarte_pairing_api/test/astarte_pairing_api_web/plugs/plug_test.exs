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

defmodule Astarte.Pairing.APIWeb.PlugTest do
  use Astarte.Pairing.APIWeb.ConnCase, async: true

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

  describe "GET /health" do
    test "returns 200 OK when status is :ready", %{conn: conn} do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:get_health, %GetHealth{}}} = Call.decode(serialized_call)

        {:ok, encoded_health_response(:READY)}
      end)

      conn = get(conn, "/health")

      assert conn.status == 200
      assert conn.halted
    end

    test "returns 200 OK when status is :degraded", %{conn: conn} do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:get_health, %GetHealth{}}} = Call.decode(serialized_call)

        {:ok, encoded_health_response(:DEGRADED)}
      end)

      conn = get(conn, "/health")

      assert conn.status == 200
      assert conn.halted
    end

    test "returns 503 when status is :bad", %{conn: conn} do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:get_health, %GetHealth{}}} = Call.decode(serialized_call)

        {:ok, encoded_health_response(:BAD)}
      end)

      conn = get(conn, "/health")

      assert conn.status == 503
      assert conn.halted
    end

    test "returns 503 when status is :error", %{conn: conn} do
      MockRPCClient
      |> expect(:rpc_call, fn serialized_call, @rpc_destination, @timeout ->
        assert %Call{call: {:get_health, %GetHealth{}}} = Call.decode(serialized_call)

        {:ok, encoded_health_response(:ERROR)}
      end)

      conn = get(conn, "/health")

      assert conn.status == 503
      assert conn.halted
    end

    test "/metrics return prometheus metrics", %{conn: conn} do
      conn = get(conn, "/metrics")
      resp_headers = Map.new(conn.resp_headers)

      assert conn.status == 200
      assert resp_headers["content-type"] =~ "text/plain"
    end
  end
end
