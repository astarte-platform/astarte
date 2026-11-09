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

defmodule Astarte.AppEngine.APIWeb.Plug.LogRealmTest do
  use Astarte.AppEngine.API.Cases.Conn, async: true

  alias Astarte.AppEngine.APIWeb.Plug.LogRealm

  test "logs the assigned realm", %{conn: conn} do
    conn
    |> assign(:realm_name, "testrealm")
    |> LogRealm.call([])

    assert Logger.metadata()[:realm] == "testrealm"
  end

  test "logs no realm when the request names none", %{conn: conn} do
    Logger.metadata(realm: "previousrealm")

    conn
    |> assign(:realm_name, nil)
    |> LogRealm.call([])

    assert Logger.metadata()[:realm] == nil
  end
end
