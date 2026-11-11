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

defmodule Astarte.Auth.GraphQL.Plug.RequireRealmHeaderTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Astarte.Auth.GraphQL.Plug.RequireRealmHeader

  defp call(conn), do: RequireRealmHeader.call(conn, RequireRealmHeader.init([]))

  defp assert_graphql_error(conn, message) do
    assert conn.halted
    assert conn.status == 200
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")
    assert %{"errors" => [%{"message" => ^message}]} = Jason.decode!(conn.resp_body)
  end

  test "assigns the realm in the header" do
    conn = conn(:post, "/v1/graphql") |> put_req_header("astarte-realm", "testrealm") |> call()

    refute conn.halted
    assert conn.assigns.realm_name == "testrealm"
  end

  test "ends the request with a GraphQL error when the header is missing" do
    conn(:post, "/v1/graphql")
    |> call()
    |> assert_graphql_error("Missing the astarte-realm header")
  end

  test "ends the request with a GraphQL error when the header is not a valid realm name" do
    conn(:post, "/v1/graphql")
    |> put_req_header("astarte-realm", "Not;A;Realm")
    |> call()
    |> assert_graphql_error("Invalid realm name in the astarte-realm header")
  end

  test "ignores a realm in the path" do
    conn(:post, "/v1/testrealm/graphql")
    |> Map.put(:path_params, %{"realm_name" => "testrealm"})
    |> call()
    |> assert_graphql_error("Missing the astarte-realm header")
  end
end
