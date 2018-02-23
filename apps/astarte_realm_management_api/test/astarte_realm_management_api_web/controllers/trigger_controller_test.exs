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

defmodule Astarte.RealmManagement.APIWeb.TriggerControllerTest do
  use Astarte.RealmManagement.APIWeb.ConnCase

  alias Astarte.RealmManagement.API.Triggers
  alias Astarte.RealmManagement.API.Triggers.Trigger

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:trigger) do
    {:ok, trigger} = RealmManagement.API.Triggers.create_trigger(@create_attrs)
    trigger
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all triggers", %{conn: conn} do
      conn = get conn, trigger_path(conn, :index)
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create trigger" do
    test "renders trigger when data is valid", %{conn: conn} do
      conn = post conn, trigger_path(conn, :create), trigger: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get conn, trigger_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id}
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, trigger_path(conn, :create), trigger: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update trigger" do
    setup [:create_trigger]

    test "renders trigger when data is valid", %{conn: conn, trigger: %Trigger{id: id} = trigger} do
      conn = put conn, trigger_path(conn, :update, trigger), trigger: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get conn, trigger_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id}
    end

    test "renders errors when data is invalid", %{conn: conn, trigger: trigger} do
      conn = put conn, trigger_path(conn, :update, trigger), trigger: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete trigger" do
    setup [:create_trigger]

    test "deletes chosen trigger", %{conn: conn, trigger: trigger} do
      conn = delete conn, trigger_path(conn, :delete, trigger)
      assert response(conn, 204)
      assert_error_sent 404, fn ->
        get conn, trigger_path(conn, :show, trigger)
      end
    end
  end

  defp create_trigger(_) do
    trigger = fixture(:trigger)
    {:ok, trigger: trigger}
  end
end
