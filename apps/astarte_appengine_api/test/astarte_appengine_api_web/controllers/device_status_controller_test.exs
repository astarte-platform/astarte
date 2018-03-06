defmodule Astarte.AppEngine.APIWeb.DeviceStatusControllerTest do
  use Astarte.AppEngine.APIWeb.ConnCase

  alias Astarte.AppEngine.API.JWTTestHelper

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
      expected_device_status = %{
        "connected" => false,
        "id" => "f0VMRgIBAQAAAAAAAAAAAA",
        "last_connection" => "2017-09-28T03:45:00.000Z",
        "last_disconnection" => "2017-09-29T18:25:00.000Z",
        "first_pairing" => "2016-08-20T09:44:00.000Z",
        "last_pairing_ip" => "4.4.4.4",
        "last_seen_ip" => "8.8.8.8",
        "total_received_bytes" => 4500000,
        "total_received_msgs" => 45000
      }

      conn = get conn, device_status_path(conn, :show, "autotestrealm", "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ")
      assert json_response(conn, 200)["data"] == expected_device_status
    end
  end
end
