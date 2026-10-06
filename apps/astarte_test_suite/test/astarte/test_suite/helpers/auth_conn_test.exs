#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.TestSuite.Helpers.AuthConnTest do
  use ExUnit.Case, async: true

  alias Plug.Conn

  alias Astarte.TestSuite.Helpers.AuthConn, as: AuthConnHelper
  alias Astarte.TestSuiteTest.AuthConfig

  describe "setup/1" do
    test "preserves conn and adds the authenticated connection" do
      conn = %Conn{}
      context = AuthConnHelper.setup(%{conn: conn, jwt: "token", claim: %{scope: "realm"}})

      assert context.conn == conn
      assert Conn.get_req_header(context.auth_conn, "authorization") == ["bearer token"]
      assert context.auth_conn_setup?
    end
  end

  describe "bind/1" do
    test "keeps the configured public key accessor unchanged when no key is provided" do
      assert :ok =
               AuthConnHelper.bind(%{
                 jwt_public_key_module: nil,
                 jwt_public_key_pem: nil
               })

      assert AuthConfig.jwt_public_key_pem() == {:ok, nil}
    end

    test "binds the configured public key in the test process" do
      assert :ok =
               AuthConnHelper.bind(%{
                 jwt_public_key_module: AuthConfig,
                 jwt_public_key_pem: "public key"
               })

      assert AuthConfig.jwt_public_key_pem() == {:ok, "public key"}
    end

    test "rejects a partial public key configuration" do
      assert_raise ArgumentError, ~r/configured together/, fn ->
        AuthConnHelper.bind(%{
          jwt_public_key_module: AuthConfig,
          jwt_public_key_pem: nil
        })
      end

      assert_raise ArgumentError, ~r/configured together/, fn ->
        AuthConnHelper.bind(%{
          jwt_public_key_module: nil,
          jwt_public_key_pem: "public key"
        })
      end
    end
  end
end
