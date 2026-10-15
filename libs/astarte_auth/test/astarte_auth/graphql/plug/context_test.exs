#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.Auth.GraphQL.Plug.ContextTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias Astarte.Auth.GraphQL.Plug.Context
  alias Astarte.Auth.TestGuardian

  @opts Context.init(
          otp_app: :astarte_auth,
          guardian: TestGuardian,
          verify_header: Guardian.Plug.VerifyHeader,
          config: Astarte.Auth.TestConfig
        )

  defp token!(claims \\ %{}) do
    {:ok, token, _claims} = TestGuardian.encode_and_sign(%{id: "testuser"}, claims)
    token
  end

  defp call(headers) do
    headers
    |> Enum.reduce(conn(:post, "/graphql"), fn {name, value}, conn ->
      put_req_header(conn, name, value)
    end)
    |> Context.call(@opts)
  end

  defp context(conn), do: conn.private[:absinthe][:context]

  test "builds a context with the authenticated user and the request's realm" do
    conn = call([{"authorization", "Bearer #{token!()}"}, {"astarte-realm", "testrealm"}])

    assert %{
             realm_name: "testrealm",
             current_user: %{id: "testuser"},
             authentication_disabled?: false
           } = context(conn)
  end

  test "carries the claims' authorizations on the current user" do
    conn =
      call([
        {"authorization", "Bearer #{token!(%{a_test: ["foo:bar"]})}"},
        {"astarte-realm", "testrealm"}
      ])

    assert %{current_user: %{authorizations: ["foo:bar"]}} = context(conn)
  end

  test "exposes the raw bearer token, for endpoints authenticated by a device secret" do
    conn = call([{"authorization", "Bearer a-credentials-secret"}])

    assert %{auth_token: "a-credentials-secret", current_user: nil} = context(conn)
  end

  test "exposes the caller's IP address" do
    conn = call([])

    assert %{remote_ip: "127.0.0.1"} = context(conn)
  end

  test "doesn't halt the connection when the token is invalid" do
    conn = call([{"authorization", "Bearer not-a-jwt"}, {"astarte-realm", "testrealm"}])

    refute conn.halted
    assert %{current_user: nil, realm_name: "testrealm"} = context(conn)
  end

  test "doesn't halt the connection when there is no token at all" do
    conn = call([{"astarte-realm", "testrealm"}])

    refute conn.halted
    assert %{current_user: nil, auth_token: nil} = context(conn)
  end

  test "reports the service's authentication_disabled? setting" do
    Application.put_env(:astarte_auth, :test_disable_authentication, true)
    on_exit(fn -> Application.delete_env(:astarte_auth, :test_disable_authentication) end)

    conn = call([])

    assert %{authentication_disabled?: true} = context(conn)
  end

  test "assigns the realm so the service's VerifyHeader can recover its public key" do
    conn = call([{"astarte-realm", "testrealm"}])

    assert conn.assigns[:realm_name] == "testrealm"
  end

  test "requires every service-specific option" do
    for missing <- [:otp_app, :guardian, :verify_header, :config] do
      opts =
        Keyword.delete(
          [
            otp_app: :astarte_auth,
            guardian: TestGuardian,
            verify_header: Guardian.Plug.VerifyHeader,
            config: Astarte.Auth.TestConfig
          ],
          missing
        )

      assert_raise KeyError, fn -> Context.init(opts) end
    end
  end
end
