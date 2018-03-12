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

defmodule Astarte.AppEngine.APIWeb.DeviceStatusByAliasController do
  use Astarte.AppEngine.APIWeb, :controller

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DeviceStatus

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  def index(conn, _params) do
    devices_by_alias = Astarte.AppEngine.API.Device.list_devices_by_alias()
    render(conn, "index.json", devices_by_alias: devices_by_alias)
  end

  def create(conn, %{"device_status_by_alias" => device_status_by_alias_params}) do
    with {:ok, %DeviceStatus{} = device_status_by_alias} <- Astarte.AppEngine.API.Device.create_device_status_by_alias(device_status_by_alias_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", device_status_by_alias_path(conn, :show, device_status_by_alias))
      |> render("show.json", device_status_by_alias: device_status_by_alias)
    end
  end

  def show(conn, %{"id" => id}) do
    device_status_by_alias = Astarte.AppEngine.API.Device.get_device_status_by_alias!(id)
    render(conn, "show.json", device_status_by_alias: device_status_by_alias)
  end

  def update(conn, %{"id" => id, "device_status_by_alias" => device_status_by_alias_params}) do
    device_status_by_alias = Astarte.AppEngine.API.Device.get_device_status_by_alias!(id)

    with {:ok, %DeviceStatus{} = device_status_by_alias} <- AppEngine.API.Device.update_device_status_by_alias(device_status_by_alias, device_status_by_alias_params) do
      render(conn, "show.json", device_status_by_alias: device_status_by_alias)
    end
  end

  def delete(conn, %{"id" => id}) do
    device_status_by_alias = Astarte.AppEngine.API.Device.get_device_status_by_alias!(id)
    with {:ok, %DeviceStatus{}} <- Astarte.AppEngine.API.Device.delete_device_status_by_alias(device_status_by_alias) do
      send_resp(conn, :no_content, "")
    end
  end
end
