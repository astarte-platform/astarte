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

defmodule Astarte.AppEngine.APIWeb.Plug.VerifyHeaderTest do
  use Astarte.AppEngine.API.Cases.Data, async: true
  use Astarte.AppEngine.API.Cases.Conn
  use Mimic

  alias Astarte.AppEngine.API.Auth
  alias Astarte.AppEngine.API.Helpers.JWT
  alias Astarte.AppEngine.APIWeb.AuthGuardian
  alias Astarte.AppEngine.APIWeb.Plug.VerifyHeader
  alias Astarte.Auth.GraphQL.Plug.Context
  alias Astarte.Auth.GraphQL.Plug.RequireRealmHeader
  alias Astarte.Auth.Plug.RequireRealmPathParam
  alias Guardian.Plug.Pipeline

  setup_all %{realm_name: realm_name} do
    JWT.install_public_key!(realm_name)
  end

  setup %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "bearer #{JWT.gen_jwt_token([])}")
      |> Phoenix.Controller.put_format("json")

    {:ok, conn: conn}
  end

  describe "on a route with the realm in the path" do
    test "verifies the token against the realm's key, ignoring the header",
         %{conn: conn, realm_name: realm_name} do
      conn =
        conn
        |> Map.put(:path_params, %{"realm_name" => realm_name})
        |> put_req_header("astarte-realm", "otherrealm")
        |> verify(RequireRealmPathParam)

      refute conn.halted
      assert %{"sub" => "testuser"} = Guardian.Plug.current_claims(conn)
    end

    test "ends the request when the realm doesn't exist", %{conn: conn} do
      conn =
        conn
        |> Map.put(:path_params, %{"realm_name" => "nosuchrealm"})
        |> verify(RequireRealmPathParam)

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "on a route without the realm in the path, with halt: false" do
    test "verifies the token against the key of the realm in the header",
         %{conn: conn, realm_name: realm_name} do
      conn =
        conn
        |> put_req_header("astarte-realm", realm_name)
        |> verify(RequireRealmHeader, halt: false)

      refute conn.halted
      assert %{"sub" => "testuser"} = Guardian.Plug.current_claims(conn)
    end

    test "leaves unauthenticated a request whose realm doesn't exist", %{conn: conn} do
      conn
      |> put_req_header("astarte-realm", "nosuchrealm")
      |> assert_unauthenticated()
    end

    # every realm is created with a key, so this state can't be set up for real
    test "leaves unauthenticated a request whose realm has no key",
         %{conn: conn, realm_name: realm_name} do
      expect(Auth, :fetch_public_key, fn ^realm_name -> {:error, :public_key_not_found} end)

      conn
      |> put_req_header("astarte-realm", realm_name)
      |> assert_unauthenticated()
    end

    test "leaves unauthenticated a request with an invalid token",
         %{conn: conn, realm_name: realm_name} do
      token = JWT.gen_jwt_token_with_wrong_signature([])

      conn
      |> put_req_header("authorization", "bearer #{token}")
      |> put_req_header("astarte-realm", realm_name)
      |> assert_unauthenticated()
    end
  end

  defp assert_unauthenticated(conn) do
    conn = verify(conn, RequireRealmHeader, halt: false)

    refute conn.halted
    assert Guardian.Plug.current_claims(conn) == nil
  end

  defp verify(conn, realm_plug, opts \\ []) do
    conn
    |> realm_plug.call(realm_plug.init([]))
    |> Pipeline.call(module: AuthGuardian, error_handler: Context.ErrorHandler)
    |> VerifyHeader.call(VerifyHeader.init(opts))
  end
end
