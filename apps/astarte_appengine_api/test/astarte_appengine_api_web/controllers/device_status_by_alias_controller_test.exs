#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.AppEngine.APIWeb.DeviceStatusByAliasControllerTest do
  use Astarte.AppEngine.APIWeb.ConnCase

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DeviceStatusByAlias

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:device_status_by_alias) do
    {:ok, device_status_by_alias} = AppEngine.API.Device.create_device_status_by_alias(@create_attrs)
    device_status_by_alias
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all devices_by_alias", %{conn: conn} do
      conn = get conn, device_status_by_alias_path(conn, :index)
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create device_status_by_alias" do
    test "renders device_status_by_alias when data is valid", %{conn: conn} do
      conn = post conn, device_status_by_alias_path(conn, :create), device_status_by_alias: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get conn, device_status_by_alias_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id}
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, device_status_by_alias_path(conn, :create), device_status_by_alias: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update device_status_by_alias" do
    setup [:create_device_status_by_alias]

    test "renders device_status_by_alias when data is valid", %{conn: conn, device_status_by_alias: %DeviceStatusByAlias{id: id} = device_status_by_alias} do
      conn = put conn, device_status_by_alias_path(conn, :update, device_status_by_alias), device_status_by_alias: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get conn, device_status_by_alias_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id}
    end

    test "renders errors when data is invalid", %{conn: conn, device_status_by_alias: device_status_by_alias} do
      conn = put conn, device_status_by_alias_path(conn, :update, device_status_by_alias), device_status_by_alias: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete device_status_by_alias" do
    setup [:create_device_status_by_alias]

    test "deletes chosen device_status_by_alias", %{conn: conn, device_status_by_alias: device_status_by_alias} do
      conn = delete conn, device_status_by_alias_path(conn, :delete, device_status_by_alias)
      assert response(conn, 204)
      assert_error_sent 404, fn ->
        get conn, device_status_by_alias_path(conn, :show, device_status_by_alias)
      end
    end
  end

  defp create_device_status_by_alias(_) do
    device_status_by_alias = fixture(:device_status_by_alias)
    {:ok, device_status_by_alias: device_status_by_alias}
  end
end
