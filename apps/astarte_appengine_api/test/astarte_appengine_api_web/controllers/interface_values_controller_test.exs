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
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.AppEngine.APIWeb.InterfaceValuesControllerTest do
  use Astarte.AppEngine.APIWeb.ConnCase

  alias Astarte.AppEngine.API.JWTTestHelper

  setup %{conn: conn} do
    {:ok, _client} = Astarte.RealmManagement.DatabaseTestHelper.create_test_keyspace()

    on_exit(fn ->
      Astarte.RealmManagement.DatabaseTestHelper.destroy_local_test_keyspace()
    end)

    authorized_conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "bearer #{JWTTestHelper.gen_jwt_all_access_token()}")

    {:ok, conn: authorized_conn}
  end

  describe "index" do
    test "lists all interfaces", %{conn: conn} do
      conn =
        get(
          conn,
          interface_values_path(
            conn,
            :index,
            "autotestrealm",
            "f0VMRgIBAQAAAAAAAAAAAA"
          )
        )

      assert json_response(conn, 200)["data"] == [
               "com.example.TestObject",
               "com.test.LCDMonitor",
               "com.test.SimpleStreamTest"
             ]
    end

    test "get interface values", %{conn: conn} do
      expected_reply = %{
        "time" => %{"from" => 8, "to" => 20},
        "lcdCommand" => "SWITCH_ON",
        "weekSchedule" => %{
          "2" => %{"start" => 12, "stop" => 15},
          "3" => %{"start" => 15, "stop" => 16},
          "4" => %{"start" => 16, "stop" => 18}
        }
      }

      from_path_conn =
        get(
          conn,
          interface_values_path(
            conn,
            :show,
            "autotestrealm",
            "f0VMRgIBAQAAAAAAAAAAAA",
            "com.test.LCDMonitor"
          )
        )

      assert json_response(from_path_conn, 200)["data"] == expected_reply

      property_conn =
        get(
          conn,
          "/v1/autotestrealm/devices/f0VMRgIBAQAAAAAAAAAAAA/interfaces/com.test.LCDMonitor/time/to"
        )

      assert json_response(property_conn, 200)["data"] == 20

      expected_reply = [
        %{"timestamp" => "2017-09-28T04:05:00.000Z", "value" => 0},
        %{"timestamp" => "2017-09-28T04:06:00.000Z", "value" => 1},
        %{"timestamp" => "2017-09-28T04:07:00.000Z", "value" => 2},
        %{"timestamp" => "2017-09-29T05:07:00.000Z", "value" => 3},
        %{"timestamp" => "2017-09-30T07:10:00.000Z", "value" => 4}
      ]

      datastream_conn =
        get(
          conn,
          "/v1/autotestrealm/devices/f0VMRgIBAQAAAAAAAAAAAA/interfaces/com.test.SimpleStreamTest/0/value"
        )

      assert json_response(datastream_conn, 200)["data"] == expected_reply

      expected_reply = [
        %{"string" => "aaa", "timestamp" => "2017-09-30T07:10:00.000Z", "value" => 1.1},
        %{"string" => "bbb", "timestamp" => "2017-09-30T07:12:00.000Z", "value" => 2.2},
        %{"string" => "ccc", "timestamp" => "2017-09-30T07:13:00.000Z", "value" => 3.3}
      ]

      object_conn =
        get(
          conn,
          "/v1/autotestrealm/devices/f0VMRgIBAQAAAAAAAAAAAA/interfaces/com.example.TestObject/"
        )

      assert json_response(object_conn, 200)["data"] == expected_reply
    end
  end
end
