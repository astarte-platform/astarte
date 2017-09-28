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
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.AppEngine.APIWeb.DeviceStatusController do
  use Astarte.AppEngine.APIWeb, :controller

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DeviceStatus

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  def index(conn, _params) do
    devices = AppEngine.API.Device.list_devices()
    render(conn, "index.json", devices: devices)
  end

  def create(conn, %{"device_status" => device_status_params}) do
    with {:ok, %DeviceStatus{} = device_status} <- AppEngine.API.Device.create_device_status(device_status_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", device_status_path(conn, :show, device_status))
      |> render("show.json", device_status: device_status)
    end
  end

  def show(conn, %{"id" => id}) do
    device_status = AppEngine.API.Device.get_device_status!(id)
    render(conn, "show.json", device_status: device_status)
  end

  def update(conn, %{"id" => id, "device_status" => device_status_params}) do
    device_status = AppEngine.API.Device.get_device_status!(id)

    with {:ok, %DeviceStatus{} = device_status} <- AppEngine.API.Device.update_device_status(device_status, device_status_params) do
      render(conn, "show.json", device_status: device_status)
    end
  end

  def delete(conn, %{"id" => id}) do
    device_status = AppEngine.API.Device.get_device_status!(id)
    with {:ok, %DeviceStatus{}} <- AppEngine.API.Device.delete_device_status(device_status) do
      send_resp(conn, :no_content, "")
    end
  end
end
