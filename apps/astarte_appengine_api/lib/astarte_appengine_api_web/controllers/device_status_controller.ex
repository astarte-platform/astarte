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

  plug Astarte.AppEngine.APIWeb.Plug.AuthorizePath

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  def index(conn, %{"realm_name" => realm_name} = params) do
    with {:ok, devices_result} <- Device.list_devices!(realm_name, params) do
      render(conn, "index.json", %{devices_list_result: devices_result, request: params})
    end
  end

  def show(conn, %{"realm_name" => realm_name, "id" => id}) do
    device_status = Device.get_device_status!(realm_name, id)
    render(conn, "show.json", device_status: device_status)
  end

  def update(_conn, %{"id" => _id, "device_status" => _device_status_params}) do
    #TODO: Astarte.AppEngine.APIWeb.DeviceStatusController.update not implemented
    #device_status = AppEngine.API.Device.get_device_status!(id)

    #with {:ok, %DeviceStatus{} = device_status} <- AppEngine.API.Device.update_device_status(device_status, device_status_params) do
    #  render(conn, "show.json", device_status: device_status)
    #end
    raise "TODO"
  end
end
