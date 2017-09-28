defmodule Astarte.AppEngine.APIWeb.DeviceStatusControllerTest do
  use Astarte.AppEngine.APIWeb.ConnCase

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DeviceStatus

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:device_status) do
    {:ok, device_status} = AppEngine.API.Device.create_device_status(@create_attrs)
    device_status
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all devices", %{conn: conn} do
      conn = get conn, device_status_path(conn, :index)
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create device_status" do
    test "renders device_status when data is valid", %{conn: conn} do
      conn = post conn, device_status_path(conn, :create), device_status: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get conn, device_status_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id}
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, device_status_path(conn, :create), device_status: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update device_status" do
    setup [:create_device_status]

    test "renders device_status when data is valid", %{conn: conn, device_status: %DeviceStatus{id: id} = device_status} do
      conn = put conn, device_status_path(conn, :update, device_status), device_status: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get conn, device_status_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id}
    end

    test "renders errors when data is invalid", %{conn: conn, device_status: device_status} do
      conn = put conn, device_status_path(conn, :update, device_status), device_status: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete device_status" do
    setup [:create_device_status]

    test "deletes chosen device_status", %{conn: conn, device_status: device_status} do
      conn = delete conn, device_status_path(conn, :delete, device_status)
      assert response(conn, 204)
      assert_error_sent 404, fn ->
        get conn, device_status_path(conn, :show, device_status)
      end
    end
  end

  defp create_device_status(_) do
    device_status = fixture(:device_status)
    {:ok, device_status: device_status}
  end
end
