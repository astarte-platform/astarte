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

defmodule Astarte.AppEngine.APIWeb.DeviceStatusByGroupControllerTest do
  use Astarte.AppEngine.APIWeb.ConnCase

  alias Astarte.AppEngine.API.DatabaseTestHelper
  alias Astarte.AppEngine.API.JWTTestHelper
  alias Astarte.AppEngine.API.Groups

  @realm "autotestrealm"
  @group_name "mygroup"
  @group_devices [
    "f0VMRgIBAQAAAAAAAAAAAA",
    "olFkumNuZ_J0f_d6-8XCDg",
    "DKxaeZ9LzUZLz7WPTTAEAA",
    "aWag-VlVKC--1S-vfzZ9uQ"
  ]

  @device_not_in_group "4UQbIokuRufdtbVZt9AsLg"

  @expected_introspection %{
    "com.example.PixelsConfiguration" => %{"major" => 1, "minor" => 0},
    "com.example.TestObject" => %{"major" => 1, "minor" => 5},
    "com.test.LCDMonitor" => %{"major" => 1, "minor" => 3},
    "com.test.SimpleStreamTest" => %{"major" => 1, "minor" => 0}
  }
  @expected_device_id "f0VMRgIBAQAAAAAAAAAAAA"
  @expected_device_status %{
    "connected" => false,
    "id" => @expected_device_id,
    "aliases" => %{"display_name" => "device_a"},
    "introspection" => @expected_introspection,
    "last_connection" => "2017-09-28T03:45:00.000Z",
    "last_disconnection" => "2017-09-29T18:25:00.000Z",
    "first_registration" => "2016-08-15T09:44:00.000Z",
    "first_credentials_request" => "2016-08-20T09:44:00.000Z",
    "last_credentials_request_ip" => "198.51.100.89",
    "last_seen_ip" => "198.51.100.81",
    "total_received_bytes" => 4_500_000,
    "total_received_msgs" => 45000,
    "groups" => [@group_name]
  }

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
    setup [:populate_group]

    test "returns 404 for non-existing group", %{conn: conn} do
      conn = get(conn, device_status_by_group_path(conn, :index, @realm, "nonexisting"))

      assert json_response(conn, 404)["errors"]["detail"] == "Group not found"
    end

    test "returns device ids for a populated group", %{conn: conn} do
      index_conn = get(conn, device_status_by_group_path(conn, :index, @realm, @group_name))

      assert devices = json_response(index_conn, 200)["data"]

      assert length(devices) == length(@group_devices)

      for device <- @group_devices do
        assert Enum.member?(devices, device)
      end
    end

    test "returns correct details", %{conn: conn} do
      index_conn =
        get(
          conn,
          device_status_by_group_path(conn, :index, @realm, @group_name, details: true)
        )

      assert devices = json_response(index_conn, 200)["data"]

      assert length(devices) == length(@group_devices)

      for device <- devices do
        %{
          "id" => device_id,
          "connected" => _,
          "aliases" => _,
          "introspection" => _,
          "last_connection" => _,
          "last_disconnection" => _,
          "first_registration" => _,
          "first_credentials_request" => _,
          "last_credentials_request_ip" => _,
          "last_seen_ip" => _,
          "total_received_bytes" => _,
          "total_received_msgs" => _,
          "groups" => [@group_name]
        } = device

        assert Enum.member?(@group_devices, device_id)
      end

      assert Enum.find(devices, &(Map.get(&1, "id") == @expected_device_id)) ==
               @expected_device_status
    end

    test "implements pagination correctly", %{conn: conn} do
      page_size = 3

      first_page_conn =
        get(
          conn,
          device_status_by_group_path(conn, :index, @realm, @group_name, limit: page_size)
        )

      assert first_page_response = json_response(first_page_conn, 200)
      first_page_devices = first_page_response["data"]
      assert length(first_page_devices) == page_size

      next_link = first_page_response["links"]["next"]

      second_page_conn = get(conn, next_link)

      assert second_page_response = json_response(second_page_conn, 200)
      second_page_devices = second_page_response["data"]
      assert length(second_page_devices) == length(@group_devices) - page_size

      assert second_page_response["links"]["self"] == next_link
      assert second_page_response["links"]["next"] == nil

      assert MapSet.disjoint?(MapSet.new(first_page_devices), MapSet.new(second_page_devices))
    end
  end

  describe "show" do
    setup [:populate_group]

    test "returns 404 with unexisting device", %{conn: conn} do
      conn =
        get(
          conn,
          device_status_by_group_path(conn, :show, @realm, @group_name, "7YZeUafPTZyEsKjO1yHIkw")
        )

      assert json_response(conn, 404)["errors"]["detail"] == "Device not found"
    end

    test "returns 404 with device not in group", %{conn: conn} do
      conn =
        get(
          conn,
          device_status_by_group_path(conn, :show, @realm, @group_name, @device_not_in_group)
        )

      assert json_response(conn, 404)["errors"]["detail"] == "Device not found"
    end

    test "returns status with valid device not in group", %{conn: conn} do
      conn =
        get(
          conn,
          device_status_by_group_path(conn, :show, @realm, @group_name, @expected_device_id)
        )

      assert json_response(conn, 200)["data"] == @expected_device_status
    end
  end

  defp populate_group(_context) do
    params = %{
      "group_name" => @group_name,
      "devices" => @group_devices
    }

    {:ok, _group} = Groups.create_group(@realm, params)

    :ok
  end
end
