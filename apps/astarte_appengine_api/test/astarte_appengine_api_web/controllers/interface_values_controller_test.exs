defmodule Astarte.AppEngine.APIWeb.InterfaceValuesControllerTest do
  use Astarte.AppEngine.APIWeb.ConnCase

  setup %{conn: conn} do
    {:ok, _client} = Astarte.RealmManagement.DatabaseTestHelper.create_test_keyspace()

    on_exit fn ->
      Astarte.RealmManagement.DatabaseTestHelper.destroy_local_test_keyspace()
    end

    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all interfaces", %{conn: conn} do
      conn = get conn, interface_values_path(conn, :index, "autotestrealm", "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ")
      assert json_response(conn, 200)["data"] == ["com.test.LCDMonitor"]
    end

    test "get interface values", %{conn: conn} do
      expected_reply = %{"time" => %{"from" => 8, "to" => 20}, "lcdCommand" => "SWITCH_ON", "weekSchedule" => %{"2" => %{"start" => 12, "stop" => 15}, "3" => %{"start" => 15, "stop" => 16}, "4" => %{"start" => 16, "stop" => 18}}}
      conn = get conn, interface_values_path(conn, :show, "autotestrealm", "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ", "com.test.LCDMonitor")
      assert json_response(conn, 200)["data"] == expected_reply

      conn = get conn, "/v1/autotestrealm/devices/f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ/interfaces/com.test.LCDMonitor/time/to"
      assert json_response(conn, 200)["data"] == 20
    end
  end
end
