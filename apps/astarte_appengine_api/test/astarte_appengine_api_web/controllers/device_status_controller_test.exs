# Copyright 2017-2023 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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

defmodule Astarte.AppEngine.APIWeb.DeviceStatusControllerTest do
  use Astarte.AppEngine.APIWeb.ConnCase

  alias Astarte.AppEngine.API.DatabaseTestHelper
  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.JWTTestHelper

  @expected_introspection %{
    "com.example.PixelsConfiguration" => %{
      "major" => 1,
      "minor" => 0,
      "exchanged_msgs" => 4230,
      "exchanged_bytes" => 2_010_000
    },
    "com.example.ServerOwnedTestObject" => %{
      "major" => 1,
      "minor" => 0,
      "exchanged_msgs" => 100,
      "exchanged_bytes" => 30_000
    },
    "com.example.TestObject" => %{
      "major" => 1,
      "minor" => 5,
      "exchanged_msgs" => 9300,
      "exchanged_bytes" => 2_000_000
    },
    "com.test.LCDMonitor" => %{
      "major" => 1,
      "minor" => 3,
      "exchanged_msgs" => 10,
      "exchanged_bytes" => 3000
    },
    "com.test.SimpleStreamTest" => %{
      "major" => 1,
      "minor" => 0,
      "exchanged_msgs" => 0,
      "exchanged_bytes" => 0
    }
  }

  @expected_previous_interfaces [
    %{
      "name" => "com.test.LCDMonitor",
      "major" => 0,
      "minor" => 1,
      "exchanged_msgs" => 42,
      "exchanged_bytes" => 9000
    }
  ]

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
    "attributes" => %{"attribute_key" => "device_a_attribute"},
    "credentials_inhibited" => false,
    "total_received_bytes" => 4_500_000,
    "total_received_msgs" => 45000,
    "previous_interfaces" => @expected_previous_interfaces,
    "groups" => [],
    "deletion_in_progress" => false
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

  describe "show" do
    test "get device_status", %{conn: conn} do
      conn =
        get(
          conn,
          device_status_path(
            conn,
            :show,
            "autotestrealm",
            "f0VMRgIBAQAAAAAAAAAAAA"
          )
        )

      assert json_response(conn, 200)["data"] == @expected_device_status
    end

    test "get device_status with invalid device id", %{conn: conn} do
      conn =
        get(
          conn,
          device_status_path(
            conn,
            :show,
            "autotestrealm",
            "f0VMRgIBA#AAAAAAAAAAAA"
          )
        )

      assert json_response(conn, 400)["errors"] == %{"detail" => "Bad request"}
    end
  end

  describe "update" do
    test "add alias to device", %{conn: conn} do
      set_device_alias_payload = %{
        "data" => %{
          "aliases" => %{
            "test_tag" => "test_alias"
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/merge-patch+json")
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "bearer #{JWTTestHelper.gen_jwt_all_access_token()}")
        |> patch(
          device_status_path(conn, :update, "autotestrealm", @expected_device_id),
          set_device_alias_payload
        )

      assert json_response(conn, 200)["data"] ==
               Map.put(@expected_device_status, "aliases", %{
                 "display_name" => "device_a",
                 "test_tag" => "test_alias"
               })

      unset_alias = %{
        "aliases" => %{
          "test_tag" => nil
        }
      }

      assert {:ok, %DeviceStatus{aliases: aliases}} =
               Device.merge_device_status("autotestrealm", @expected_device_id, unset_alias)

      assert Enum.member?(aliases, "test_tag") == false
    end

    test "remove device alias", %{conn: conn} do
      set_alias = %{
        "aliases" => %{
          "test_tag" => "test_alias"
        }
      }

      assert {:ok, %DeviceStatus{aliases: %{"test_tag" => "test_alias"}}} =
               Device.merge_device_status("autotestrealm", @expected_device_id, set_alias)

      unset_device_alias_payload = %{
        "data" => %{
          "aliases" => %{
            "test_tag" => nil
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/merge-patch+json")
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "bearer #{JWTTestHelper.gen_jwt_all_access_token()}")
        |> patch(
          device_status_path(conn, :update, "autotestrealm", @expected_device_id),
          unset_device_alias_payload
        )

      assert json_response(conn, 200)["data"] ==
               Map.put(@expected_device_status, "aliases", %{"display_name" => "device_a"})
    end

    test "updates credentials_inhibited with valid params", %{conn: conn} do
      data = %{
        "credentials_inhibited" => true
      }

      conn =
        conn
        |> put_req_header("content-type", "application/merge-patch+json")
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "bearer #{JWTTestHelper.gen_jwt_all_access_token()}")
        |> patch(
          device_status_path(conn, :update, "autotestrealm", @expected_device_id),
          data: data
        )

      assert json_response(conn, 200)["data"]["credentials_inhibited"] == true
    end

    test "fails to update credentials_inhibited with invalid params", %{conn: conn} do
      data = %{
        "credentials_inhibited" => "foobar"
      }

      conn =
        conn
        |> put_req_header("content-type", "application/merge-patch+json")
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "bearer #{JWTTestHelper.gen_jwt_all_access_token()}")
        |> patch(
          device_status_path(conn, :update, "autotestrealm", @expected_device_id),
          data: data
        )

      assert json_response(conn, 422)["errors"]["credentials_inhibited"] != nil
    end
  end

  describe "index" do
    test "index all devices with default limit", %{conn: conn} do
      expected_all_devices_list = %{
        "data" => [
          "4UQbIokuRufdtbVZt9AsLg",
          "DKxaeZ9LzUZLz7WPTTAEAA",
          "aWag-VlVKC--1S-vfzZ9uQ",
          "ehNpbPVtQ2CcdJdJK3QUlA",
          "f0VMRgIBAQAAAAAAAAAAAA",
          "olFkumNuZ_J0f_d6-8XCDg"
        ],
        "links" => %{
          "self" => "/v1/autotestrealm/devices"
        }
      }

      conn = get(conn, device_status_path(conn, :index, "autotestrealm"))
      assert sort_devices_list(json_response(conn, 200)) == expected_all_devices_list
    end

    test "index all devices with limit set to 5", %{conn: conn} do
      expected_all_devices_list_with_limit5 = %{
        "data" => [
          "4UQbIokuRufdtbVZt9AsLg",
          "DKxaeZ9LzUZLz7WPTTAEAA",
          "aWag-VlVKC--1S-vfzZ9uQ",
          "f0VMRgIBAQAAAAAAAAAAAA",
          "olFkumNuZ_J0f_d6-8XCDg"
        ],
        "links" => %{
          "self" => "/v1/autotestrealm/devices?limit=5"
        }
      }

      conn = get(conn, device_status_path(conn, :index, "autotestrealm", %{"limit" => 5}))
      # TODO: a link to the next (empty) page is returned, so we are not going to test it now.
      # Automatic pagination should be used instead with saved state.
      # assert sort_devices_list(json_response(conn, 200)) == expected_all_devices_list_with_limit5
      # WORKAROUND: we are testing a bit less:
      assert sort_devices_list(json_response(conn, 200))["data"] ==
               expected_all_devices_list_with_limit5["data"]
    end

    test "index up to 2 devices", %{conn: conn} do
      conn = get(conn, device_status_path(conn, :index, "autotestrealm", %{"limit" => 2}))
      response_with_limit2 = sort_devices_list(json_response(conn, 200))

      assert response_with_limit2["links"]["self"] == "/v1/autotestrealm/devices?limit=2"
      assert URI.parse(response_with_limit2["links"]["next"]).path == "/v1/autotestrealm/devices"

      %{"limit" => "2", "from_token" => _} =
        URI.decode_query(URI.parse(response_with_limit2["links"]["next"]).query)

      assert length(response_with_limit2["data"]) == 2
      assert Enum.sort(Map.keys(response_with_limit2["links"])) == ["next", "self"]
    end

    test "index all devices with details", %{conn: conn} do
      conn = get(conn, device_status_path(conn, :index, "autotestrealm", %{"details" => true}))
      response = json_response(conn, 200)

      assert Enum.find(response["data"], fn dev -> dev["id"] == @expected_device_id end) ==
               @expected_device_status

      assert response["links"]["self"] == "/v1/autotestrealm/devices?details=true"
      assert Map.has_key?(response["links"], "next") == false
    end
  end

  defp sort_devices_list(response) do
    sorted_data =
      response["data"]
      |> Enum.sort()

    Map.put(response, "data", sorted_data)
  end
end
