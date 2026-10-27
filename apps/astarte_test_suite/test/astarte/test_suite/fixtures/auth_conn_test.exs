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

defmodule Astarte.TestSuite.Fixtures.AuthConnTest do
  use ExUnit.Case, async: true

  alias Plug.Conn

  alias Astarte.TestSuite.Fixtures.AuthConn, as: AuthConnFixtures

  test "auth_conn setup fixture adds authorization header" do
    context = AuthConnFixtures.setup(%{conn: %Conn{}, jwt: "token", claim: %{scope: "realm"}})

    assert Plug.Conn.get_req_header(context.conn, "authorization") == ["bearer token"]
    assert context.auth_conn_setup?
  end
end
