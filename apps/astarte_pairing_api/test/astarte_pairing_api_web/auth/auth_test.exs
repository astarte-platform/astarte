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
# Copyright (C) 2018 Ispirata Srl
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

      assert json_response(conn, 403)["errors"]["detail"] == "Forbidden"
    end

    test "fails with authorization for different method", %{conn: conn} do
      register_authorizations = ["GET::agent/dev"]

      conn =
        conn
        |> authorize_conn(register_authorizations)
        |> post(agent_path(conn, :create, @realm), data: @create_attrs)

      assert json_response(conn, 403)["errors"]["detail"] == "Forbidden"
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
