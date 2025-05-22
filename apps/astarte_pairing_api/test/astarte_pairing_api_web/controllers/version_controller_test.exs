#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.APIWeb.VersionControllerTest do
  use Astarte.Pairing.APIWeb.ConnCase, async: true

  alias Astarte.Pairing.APIWeb.Helpers.JWTTestHelper

  @realm "testrealm"
  @expected_version Mix.Project.config()[:version]

  setup %{conn: conn} do
    jwt = JWTTestHelper.gen_jwt_all_access_token()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "bearer #{jwt}")

    {:ok, conn: conn}
  end

  describe "GET /version" do
    test "returns the app version", %{conn: conn} do
      conn = get(conn, version_path(conn, :show))
      assert json_response(conn, 200) == %{"data" => @expected_version}
    end
  end

  describe "GET /v1/:realm_name/version" do
    test "returns the app version with realm", %{conn: conn} do
      conn = get(conn, "/v1/#{@realm}/version")
      assert json_response(conn, 200) == %{"data" => @expected_version}
    end
  end
end
