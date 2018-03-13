#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.AppEngine.APIWeb.DeviceStatusByAliasControllerTest do
  use Astarte.AppEngine.APIWeb.ConnCase

  alias Astarte.AppEngine.API.JWTTestHelper

  @expected_device_status %{
        "connected" => false,
        "id" => "f0VMRgIBAQAAAAAAAAAAAA",
        "aliases" => %{"display_name" => "device_a"},
        "last_connection" => "2017-09-28T03:45:00.000Z",
        "last_disconnection" => "2017-09-29T18:25:00.000Z",
        "first_pairing" => "2016-08-20T09:44:00.000Z",
        "last_pairing_ip" => "4.4.4.4",
        "last_seen_ip" => "8.8.8.8",
        "total_received_bytes" => 4500000,
        "total_received_msgs" => 45000
  }

  setup %{conn: conn} do
    {:ok, _client} = Astarte.RealmManagement.DatabaseTestHelper.create_test_keyspace()

    on_exit fn ->
      Astarte.RealmManagement.DatabaseTestHelper.destroy_local_test_keyspace()
    end

    authorized_conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "bearer #{JWTTestHelper.gen_jwt_all_access_token()}")

    {:ok, conn: authorized_conn}
  end

  describe "show" do
    test "get device_status", %{conn: conn} do
      conn = get conn, device_status_by_alias_path(conn, :show, "autotestrealm", "device_a")
      assert json_response(conn, 200)["data"] == @expected_device_status
    end
  end
end
