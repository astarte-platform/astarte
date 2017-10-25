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
      assert json_response(conn, 200)["data"] == ["com.example.TestObject", "com.test.LCDMonitor", "com.test.SimpleStreamTest"]
    end

    test "get interface values", %{conn: conn} do
      expected_reply = %{"time" => %{"from" => 8, "to" => 20}, "lcdCommand" => "SWITCH_ON", "weekSchedule" => %{"2" => %{"start" => 12, "stop" => 15}, "3" => %{"start" => 15, "stop" => 16}, "4" => %{"start" => 16, "stop" => 18}}}
      conn = get conn, interface_values_path(conn, :show, "autotestrealm", "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ", "com.test.LCDMonitor")
      assert json_response(conn, 200)["data"] == expected_reply

      conn = get conn, "/v1/autotestrealm/devices/f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ/interfaces/com.test.LCDMonitor/time/to"
      assert json_response(conn, 200)["data"] == 20

      expected_reply = [
        %{"timestamp" => "2017-09-28T04:05:00.000Z", "value" => 0},
        %{"timestamp" => "2017-09-28T04:06:00.000Z", "value" => 1},
        %{"timestamp" => "2017-09-28T04:07:00.000Z", "value" => 2},
        %{"timestamp" => "2017-09-29T05:07:00.000Z", "value" => 3},
        %{"timestamp" => "2017-09-30T07:10:00.000Z", "value" => 4}
      ]
      conn = get conn, "/v1/autotestrealm/devices/f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ/interfaces/com.test.SimpleStreamTest/0/value"
      assert json_response(conn, 200)["data"] == expected_reply
    end
  end
end
