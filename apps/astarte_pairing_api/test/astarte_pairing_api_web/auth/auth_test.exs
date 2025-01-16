#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.Pairing.APIWeb.AuthTest do
  use Astarte.Pairing.APIWeb.ConnCase

  alias Astarte.Pairing.APIWeb.JWTTestHelper

  alias Astarte.RPC.Protocol.Pairing.{
    GetAgentPublicKeyPEMsReply,
    RegisterDeviceReply,
    Reply
  }

  import Mox

  @realm "testrealm"
  @hw_id "2imLILqtRP2vq0ZVy-TGRQ"
  @create_attrs %{"hw_id" => @hw_id}
  @credentials_secret "supersecret"

  describe "JWT auth" do
    setup %{conn: conn} do
      setup_mock_rpc()

      conn =
        conn
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn}
    end

    test "no token returns 401", %{conn: conn} do
      conn = post(conn, agent_path(conn, :create, @realm), data: @create_attrs)
      assert json_response(conn, 401)["errors"]["detail"] == "Missing authorization token"
    end

    test "succeeds with specific authorizations", %{conn: conn} do
      register_authorizations = ["POST::agent/devices"]

      conn =
        conn
        |> authorize_conn(register_authorizations)
        |> post(agent_path(conn, :create, @realm), data: @create_attrs)

      assert %{"credentials_secret" => @credentials_secret} = json_response(conn, 201)["data"]
    end

    test "succeeds with all access authorizations", %{conn: conn} do
      register_authorizations = [".*::.*"]

      conn =
        conn
        |> authorize_conn(register_authorizations)
        |> post(agent_path(conn, :create, @realm), data: @create_attrs)

      assert %{"credentials_secret" => @credentials_secret} = json_response(conn, 201)["data"]
    end

    test "succeeds with explicitly terminated authorization regex", %{conn: conn} do
      register_authorizations = ["^POST$::^agent/devices$"]

      conn =
        conn
        |> authorize_conn(register_authorizations)
        |> post(agent_path(conn, :create, @realm), data: @create_attrs)

      assert %{"credentials_secret" => @credentials_secret} = json_response(conn, 201)["data"]
    end

    test "fails with authorization for path prefix", %{conn: conn} do
      register_authorizations = ["POST::agent/dev"]

      conn =
        conn
        |> authorize_conn(register_authorizations)
        |> post(agent_path(conn, :create, @realm), data: @create_attrs)

      assert json_response(conn, 403)["errors"]["detail"] ==
               "Unauthorized access to #{conn.assigns.method} #{conn.assigns.path}. Please verify your permissions"
    end

    test "fails with authorization for different method", %{conn: conn} do
      register_authorizations = ["GET::agent/dev"]

      conn =
        conn
        |> authorize_conn(register_authorizations)
        |> post(agent_path(conn, :create, @realm), data: @create_attrs)

      assert json_response(conn, 403)["errors"]["detail"] ==
               "Unauthorized access to #{conn.assigns.method} #{conn.assigns.path}. Please verify your permissions"
    end

    test "invalid JWT token returns 401", %{conn: conn} do
      conn =
        put_req_header(
          conn,
          "authorization",
          "bearer invalid_token"
        )
        |> post(agent_path(conn, :create, @realm), data: @create_attrs)

      assert json_response(conn, 401)["errors"]["detail"] == "Invalid JWT token"
    end

    test "token with mismatched signature returns 401", %{conn: conn} do
      token = JWTTestHelper.gen_jwt_token_with_wrong_signature(["^POST$::agent/devices"])

      conn =
        put_req_header(conn, "authorization", "bearer #{token}")
        |> post(agent_path(conn, :create, @realm), data: @create_attrs)

      assert json_response(conn, 401)["errors"]["detail"] == "Invalid JWT token"
    end
  end

  defp authorize_conn(conn, authorizations) when is_list(authorizations) do
    token = JWTTestHelper.gen_jwt_token(authorizations)
    put_req_header(conn, "authorization", "bearer #{token}")
  end

  defp setup_mock_rpc do
    rpc_destination = Astarte.RPC.Protocol.Pairing.amqp_queue()
    timeout = 30_000

    agent_public_key_pems = JWTTestHelper.agent_public_key_pems()

    encoded_pubkey_response =
      %Reply{
        reply:
          {:get_agent_public_key_pems_reply,
           %GetAgentPublicKeyPEMsReply{
             agent_public_key_pems: agent_public_key_pems
           }}
      }
      |> Reply.encode()

    pubkey_fun = fn _call, ^rpc_destination, ^timeout -> {:ok, encoded_pubkey_response} end

    encoded_register_response =
      %Reply{
        reply:
          {:register_device_reply, %RegisterDeviceReply{credentials_secret: @credentials_secret}}
      }
      |> Reply.encode()

    register_fun = fn _call, ^rpc_destination, ^timeout -> {:ok, encoded_register_response} end

    MockRPCClient
    |> expect(:rpc_call, pubkey_fun)
    |> expect(:rpc_call, register_fun)
  end
end
