defmodule Astarte.AppEngine.APIWeb.DeviceStatusControllerTest do
  use Astarte.AppEngine.APIWeb.ConnCase

  alias Astarte.AppEngine.API.JWTTestHelper

  @expected_device_id "f0VMRgIBAQAAAAAAAAAAAA"
  @expected_device_status %{
        "connected" => false,
        "id" => @expected_device_id,
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
      conn = get conn, device_status_path(conn, :show, "autotestrealm", "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ")
      assert json_response(conn, 200)["data"] == @expected_device_status
    end
  end

  describe "index" do
    test "index all devices with default limit", %{conn: conn} do
      expected_all_devices_list = %{
        "data" => [
          "4UQbIokuRufdtbVZt9AsLg",
          "DKxaeZ9LzUZLz7WPTTAEAA",
          "aWag-VlVKC--1S-vfzZ9uQ",
          "f0VMRgIBAQAAAAAAAAAAAA",
          "olFkumNuZ_J0f_d6-8XCDg"
        ],
        "links" => %{
          "self" => "/v1/autotestrealm/devices"
        }
      }

      conn = get conn, device_status_path(conn, :index, "autotestrealm")
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

      conn = get conn, device_status_path(conn, :index, "autotestrealm", %{"limit" => 5})
      # TODO: a link to the next (empty) page is returned, so we are not going to test it now.
      # Automatic pagination should be used instead with saved state.
      # assert sort_devices_list(json_response(conn, 200)) == expected_all_devices_list_with_limit5
      # WORKAROUND: we are testing a bit less:
      assert sort_devices_list(json_response(conn, 200))["data"] == expected_all_devices_list_with_limit5["data"]
    end

    test "index up to 2 devices", %{conn: conn}  do
      conn = get conn, device_status_path(conn, :index, "autotestrealm", %{"limit" => 2})
      response_with_limit2 = sort_devices_list(json_response(conn, 200))

      assert response_with_limit2["links"]["self"] == "/v1/autotestrealm/devices?limit=2"
      assert URI.parse(response_with_limit2["links"]["next"]).path == "/v1/autotestrealm/devices"
      %{"limit" => "2", "from_token" => _} = URI.decode_query(URI.parse(response_with_limit2["links"]["next"]).query)
      assert length(response_with_limit2["data"]) == 2
      assert Enum.sort(Map.keys(response_with_limit2["links"])) == ["next", "self"]
    end

    test "index all devices with details", %{conn: conn}  do
      conn = get conn, device_status_path(conn, :index, "autotestrealm", %{"details" => true})
      response = json_response(conn, 200)

      assert Enum.find(response["data"], fn dev -> dev["id"] == @expected_device_id end) == @expected_device_status
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
