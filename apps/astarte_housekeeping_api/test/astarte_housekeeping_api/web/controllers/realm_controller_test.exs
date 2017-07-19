defmodule Astarte.Housekeeping.API.Web.RealmControllerTest do
  use Astarte.Housekeeping.API.Web.ConnCase

  alias Astarte.Housekeeping.API.Realms
  alias Astarte.Housekeeping.API.Realms.Realm

  @create_attrs %{"realm_name" => "testrealm"}
  @update_attrs %{}
  @invalid_attrs %{"realm_name" => "0invalid"}

  def fixture(:realm) do
    {:ok, realm} = Housekeeping.API.Realms.create_realm(@create_attrs)
    realm
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @tag :wip
  test "lists all entries on index", %{conn: conn} do
    conn = get conn, realm_path(conn, :index)
    assert json_response(conn, 200)["data"] == []
  end

  test "creates realm and renders realm when data is valid", %{conn: conn} do
    conn = post conn, realm_path(conn, :create), realm: @create_attrs
    assert %{"id" => id} = json_response(conn, 201)["data"]

    conn = get conn, realm_path(conn, :show, id)
    assert json_response(conn, 200)["data"] == %{
      "id" => id}
  end

  test "does not create realm and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, realm_path(conn, :create), realm: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  @tag :wip
  test "updates chosen realm and renders realm when data is valid", %{conn: conn} do
    %Realm{id: id} = realm = fixture(:realm)
    conn = put conn, realm_path(conn, :update, realm), realm: @update_attrs
    assert %{"id" => ^id} = json_response(conn, 200)["data"]

    conn = get conn, realm_path(conn, :show, id)
    assert json_response(conn, 200)["data"] == %{
      "id" => id}
  end

  @tag :wip
  test "does not update chosen realm and renders errors when data is invalid", %{conn: conn} do
    realm = fixture(:realm)
    conn = put conn, realm_path(conn, :update, realm), realm: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  @tag :wip
  test "deletes chosen realm", %{conn: conn} do
    realm = fixture(:realm)
    conn = delete conn, realm_path(conn, :delete, realm)
    assert response(conn, 204)
    assert_error_sent 404, fn ->
      get conn, realm_path(conn, :show, realm)
    end
  end
end
