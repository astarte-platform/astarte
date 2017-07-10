defmodule Astarte.RealmManagement.API.Web.InterfaceControllerTest do
  use Astarte.RealmManagement.API.Web.ConnCase

  alias Astarte.RealmManagement.API.Interfaces
  alias Astarte.RealmManagement.API.Interfaces.Interface

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:interface) do
    {:ok, interface} = RealmManagement.API.Interfaces.create_interface(@create_attrs)
    interface
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, interface_path(conn, :index)
    assert json_response(conn, 200)["data"] == []
  end

  test "creates interface and renders interface when data is valid", %{conn: conn} do
    conn = post conn, interface_path(conn, :create), interface: @create_attrs
    assert %{"id" => id} = json_response(conn, 201)["data"]

    conn = get conn, interface_path(conn, :show, id)
    assert json_response(conn, 200)["data"] == %{
      "id" => id}
  end

  test "does not create interface and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, interface_path(conn, :create), interface: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates chosen interface and renders interface when data is valid", %{conn: conn} do
    %Interface{id: id} = interface = fixture(:interface)
    conn = put conn, interface_path(conn, :update, interface), interface: @update_attrs
    assert %{"id" => ^id} = json_response(conn, 200)["data"]

    conn = get conn, interface_path(conn, :show, id)
    assert json_response(conn, 200)["data"] == %{
      "id" => id}
  end

  test "does not update chosen interface and renders errors when data is invalid", %{conn: conn} do
    interface = fixture(:interface)
    conn = put conn, interface_path(conn, :update, interface), interface: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen interface", %{conn: conn} do
    interface = fixture(:interface)
    conn = delete conn, interface_path(conn, :delete, interface)
    assert response(conn, 204)
    assert_error_sent 404, fn ->
      get conn, interface_path(conn, :show, interface)
    end
  end
end
