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

defmodule Astarte.Auth.Plug.FetchRealmNameTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Astarte.Auth.Plug.FetchRealmName

  defp realm_name(conn) do
    conn
    |> FetchRealmName.call(FetchRealmName.init([]))
    |> Map.fetch!(:assigns)
    |> Map.fetch!(:realm_name)
  end

  test "takes the realm in the path, over the one in the header" do
    conn =
      conn(:get, "/v1/pathrealm/devices")
      |> Map.put(:path_params, %{"realm_name" => "pathrealm"})
      |> put_req_header("astarte-realm", "headerrealm")

    assert realm_name(conn) == "pathrealm"
  end

  test "takes the realm in the header, on a route without one in the path" do
    conn = conn(:post, "/v1/graphql") |> put_req_header("astarte-realm", "headerrealm")

    assert realm_name(conn) == "headerrealm"
  end

  test "has no realm when the header is missing" do
    assert realm_name(conn(:post, "/v1/graphql")) == nil
  end

  test "has no realm when the header is not a valid realm name" do
    conn = conn(:post, "/v1/graphql") |> put_req_header("astarte-realm", "Not;A;Realm")

    assert realm_name(conn) == nil
  end
end
