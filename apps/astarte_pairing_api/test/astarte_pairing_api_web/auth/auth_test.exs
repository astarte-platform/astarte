#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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
  use Astarte.Cases.Data, async: true
  use Astarte.Pairing.APIWeb.ConnCase, async: true

  alias Astarte.Pairing.APIWeb.Helpers.JWTTestHelper

  @hw_id "2imLILqtRP2vq0ZVy-TGRQ"
  @create_attrs %{"hw_id" => @hw_id}

  describe "JWT auth" do
    setup %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn}
    end

    test "succeeds with specific authorizations", %{conn: conn, realm_name: realm_name} do
      register_authorizations = ["POST::agent/devices"]

      conn =
        conn
        |> authorize_conn(register_authorizations)
        |> post(agent_path(conn, :create, realm_name), data: @create_attrs)

      assert %{"credentials_secret" => credentials_secret} = json_response(conn, 201)["data"]
      assert is_binary(credentials_secret)
    end

    test "succeeds with all access authorizations", %{conn: conn, realm_name: realm_name} do
      register_authorizations = [".*::.*"]

      conn =
        conn
        |> authorize_conn(register_authorizations)
        |> post(agent_path(conn, :create, realm_name), data: @create_attrs)

      assert %{"credentials_secret" => credentials_secret} = json_response(conn, 201)["data"]
      assert is_binary(credentials_secret)
    end

    test "succeeds with explicitly terminated authorization regex", %{
      conn: conn,
      realm_name: realm_name
    } do
      register_authorizations = ["^POST$::^agent/devices$"]

      conn =
        conn
        |> authorize_conn(register_authorizations)
        |> post(agent_path(conn, :create, realm_name), data: @create_attrs)

      assert %{"credentials_secret" => credentials_secret} = json_response(conn, 201)["data"]
      assert is_binary(credentials_secret)
    end

    test "fails with authorization for path prefix", %{conn: conn, realm_name: realm_name} do
      register_authorizations = ["POST::agent/dev"]

      conn =
        conn
        |> authorize_conn(register_authorizations)
        |> post(agent_path(conn, :create, realm_name), data: @create_attrs)

      assert json_response(conn, 403)["errors"]["detail"] == "Forbidden"
    end

    test "fails with authorization for different method", %{conn: conn, realm_name: realm_name} do
      register_authorizations = ["GET::agent/dev"]

      conn =
        conn
        |> authorize_conn(register_authorizations)
        |> post(agent_path(conn, :create, realm_name), data: @create_attrs)

      assert json_response(conn, 403)["errors"]["detail"] == "Forbidden"
    end
  end

  defp authorize_conn(conn, authorizations) when is_list(authorizations) do
    token = JWTTestHelper.gen_jwt_token(authorizations)
    put_req_header(conn, "authorization", "bearer #{token}")
  end
end
