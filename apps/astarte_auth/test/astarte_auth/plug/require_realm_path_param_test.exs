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

defmodule Astarte.Auth.Plug.RequireRealmPathParamTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Astarte.Auth.Plug.RequireRealmPathParam

  defp call(conn), do: RequireRealmPathParam.call(conn, RequireRealmPathParam.init([]))

  defp in_path(conn, realm_name), do: Map.put(conn, :path_params, %{"realm_name" => realm_name})

  test "assigns the realm in the path" do
    conn = conn(:get, "/v1/testrealm/devices") |> in_path("testrealm") |> call()

    refute conn.halted
    assert conn.assigns.realm_name == "testrealm"
  end

  test "ends the request with a 401 when the path has an invalid realm name" do
    conn = conn(:get, "/v1/Not;A;Realm/devices") |> in_path("Not;A;Realm") |> call()

    assert conn.halted
    assert conn.status == 401
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")
    assert conn.resp_body == ~s({"errors":{"detail":"Invalid realm name"}})
  end

  test "ignores a realm in the header" do
    conn =
      conn(:get, "/v1/testrealm/devices")
      |> in_path("testrealm")
      |> put_req_header("astarte-realm", "otherrealm")
      |> call()

    assert conn.assigns.realm_name == "testrealm"
  end
end
