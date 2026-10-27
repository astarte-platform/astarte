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
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Astarte.Auth.GraphQL.Plug.Context

  defp call(headers, current_user \\ nil) do
    headers
    |> Enum.reduce(conn(:post, "/graphql"), fn {name, value}, conn ->
      put_req_header(conn, name, value)
    end)
    |> Guardian.Plug.put_current_resource(current_user)
    |> Context.call(Context.init([]))
  end

  defp context(conn), do: conn.private[:absinthe][:context]

  test "builds a context with the loaded user and the request's realm" do
    user = %{id: "testuser", roles: ["fdo_manager"]}

    conn = call([{"astarte-realm", "testrealm"}], user)

    assert %{realm_name: "testrealm", current_user: ^user} = context(conn)
  end

  test "has no realm when the astarte-realm header is missing or not a valid realm name" do
    assert %{realm_name: nil} = context(call([]))
    assert %{realm_name: nil} = context(call([{"astarte-realm", "Bad!"}]))
  end

  test "has no current user when Guardian didn't load one" do
    conn = call([{"authorization", "Bearer not-a-jwt"}, {"astarte-realm", "testrealm"}])

    assert %{current_user: nil, realm_name: "testrealm"} = context(conn)
  end

  test "exposes the raw bearer token, for endpoints authenticated by a device secret" do
    conn = call([{"authorization", "Bearer a-credentials-secret"}])

    assert %{auth_token: "a-credentials-secret", current_user: nil} = context(conn)
  end

  test "has no bearer token when no authorization header is a bearer one" do
    conn = call([{"authorization", "Basic dXNlcjpwYXNz"}])

    assert %{auth_token: nil} = context(conn)
  end

  test "exposes the caller's IP address" do
    conn = call([])

    assert %{remote_ip: "127.0.0.1"} = context(conn)
  end
end
