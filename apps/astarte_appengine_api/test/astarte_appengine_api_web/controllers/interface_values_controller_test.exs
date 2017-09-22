defmodule AstarteAppengineApiWeb.InterfaceValuesControllerTest do
  use AstarteAppengineApiWeb.ConnCase

  alias AstarteAppengineApi.Device
  alias AstarteAppengineApi.Device.InterfaceValues

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:interface_values) do
    {:ok, interface_values} = Device.create_interface_values(@create_attrs)
    interface_values
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all interfaces", %{conn: conn} do
      conn = get conn, interface_values_path(conn, :index)
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create interface_values" do
    test "renders interface_values when data is valid", %{conn: conn} do
      conn = post conn, interface_values_path(conn, :create), interface_values: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get conn, interface_values_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id}
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, interface_values_path(conn, :create), interface_values: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update interface_values" do
    setup [:create_interface_values]

    test "renders interface_values when data is valid", %{conn: conn, interface_values: %InterfaceValues{id: id} = interface_values} do
      conn = put conn, interface_values_path(conn, :update, interface_values), interface_values: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get conn, interface_values_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id}
    end

    test "renders errors when data is invalid", %{conn: conn, interface_values: interface_values} do
      conn = put conn, interface_values_path(conn, :update, interface_values), interface_values: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete interface_values" do
    setup [:create_interface_values]

    test "deletes chosen interface_values", %{conn: conn, interface_values: interface_values} do
      conn = delete conn, interface_values_path(conn, :delete, interface_values)
      assert response(conn, 204)
      assert_error_sent 404, fn ->
        get conn, interface_values_path(conn, :show, interface_values)
      end
    end
  end

  defp create_interface_values(_) do
    interface_values = fixture(:interface_values)
    {:ok, interface_values: interface_values}
  end
end
