defmodule AstarteAppengineApiWeb.InterfaceValuesControllerTest do
  use AstarteAppengineApiWeb.ConnCase

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
      conn = get conn, interface_values_path(conn, :show, "autotestrealm", "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ", "com.test.LCDMonitor")
      assert json_response(conn, 200)["data"] == %{"time" => %{"from" => 8, "to" => 20}}

      conn = get conn, interface_values_path(conn, :show, "autotestrealm", "f0VMRgIBAQAAAAAAAAAAAAIAPgABAAAAsCVAAAAAAABAAAAAAAAAADDEAAAAAAAAAAAAAEAAOAAJ", "com.test.LCDMonitor", %{ "path" =>"time/to"})
      assert json_response(conn, 200)["data"] == 20
    end
  end
end
