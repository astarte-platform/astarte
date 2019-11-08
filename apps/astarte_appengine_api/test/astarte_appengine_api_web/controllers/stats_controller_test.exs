#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.AppEngine.APIWeb.StatsControllerTest do
  use Astarte.AppEngine.APIWeb.ConnCase

  alias Astarte.AppEngine.API.DatabaseTestHelper
  alias Astarte.AppEngine.API.JWTTestHelper

  setup_all do
    {:ok, _client} = DatabaseTestHelper.create_test_keyspace()

    on_exit(fn ->
      DatabaseTestHelper.destroy_local_test_keyspace()
    end)

    :ok
  end

  setup %{conn: conn} do
    DatabaseTestHelper.seed_data()

    authorized_conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "bearer #{JWTTestHelper.gen_jwt_all_access_token()}")

    {:ok, conn: authorized_conn}
  end

  describe "show_devices_stats" do
    test "returns JSON devices stats", %{conn: conn} do
      conn = get(conn, stats_path(conn, :show_devices_stats, "autotestrealm"))

      assert json_response(conn, 200)["data"] == %{
               "total_devices" => DatabaseTestHelper.devices_count(),
               "connected_devices" => 0
             }
    end

    test "returns updated stats after device connection", %{conn: conn} do
      DatabaseTestHelper.fake_connect_device("f0VMRgIBAQAAAAAAAAAAAA", true)

      conn = get(conn, stats_path(conn, :show_devices_stats, "autotestrealm"))

      assert json_response(conn, 200)["data"] == %{
               "total_devices" => DatabaseTestHelper.devices_count(),
               "connected_devices" => 1
             }
    end
  end
end
