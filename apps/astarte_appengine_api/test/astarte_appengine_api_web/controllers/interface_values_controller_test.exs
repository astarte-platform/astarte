# Copyright 2017-2023 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule Astarte.AppEngine.APIWeb.InterfaceValuesControllerTest do
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

  describe "index" do
    test "lists all interfaces using a invalid device id", %{conn: conn} do
      conn =
        get(
          conn,
          interface_values_path(
            conn,
            :index,
            "autotestrealm",
            "zzzzzzzzzzzf0VMRgIBAQAAAAAAAAAAAA"
          )
        )

      assert json_response(conn, 400)["errors"] == %{"detail" => "Bad request"}
    end

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

      assert Enum.sort(json_response(conn, 200)["data"]) == [
               "com.example.PixelsConfiguration",
               "com.example.ServerOwnedTestObject",
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
        %{"timestamp" => "2017-09-28T04:05:00.000Z", "value" => 0},
        %{"timestamp" => "2017-09-28T04:07:00.000Z", "value" => 2},
        %{"timestamp" => "2017-09-30T07:10:00.000Z", "value" => 4}
      ]

      downsampled_conn =
        get(
          conn,
          "/v1/autotestrealm/devices/f0VMRgIBAQAAAAAAAAAAAA/interfaces/com.test.SimpleStreamTest/0/value?downsample_to=3"
        )

      assert json_response(downsampled_conn, 200)["data"] == expected_reply

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

  describe "update" do
    test "returns an error when given invalid keys", %{conn: conn} do
      conn =
        put(
          conn,
          interface_values_path(
            conn,
            :update,
            "autotestrealm",
            "f0VMRgIBAQAAAAAAAAAAAA",
            "com.example.ServerOwnedTestObject",
            ["my_path"]
          ),
          %{
            data: %{"string" => "aaa", "invalidKey" => true}
          }
        )

      assert json_response(conn, 400)["errors"] == %{"detail" => "Unexpected object key"}
    end
  end
end
