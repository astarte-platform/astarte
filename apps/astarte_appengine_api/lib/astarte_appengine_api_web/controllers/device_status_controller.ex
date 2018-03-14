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
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.AppEngine.API.Device.DeviceStatus

  plug Astarte.AppEngine.APIWeb.Plug.AuthorizePath

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  def index(conn, %{"realm_name" => realm_name} = params) do
    with {:ok, %DevicesList{} = devices_list} <- Device.list_devices!(realm_name, params) do
      render(conn, "index.json", %{devices_list: devices_list, request: params})
    end
  end

  def show(conn, %{"realm_name" => realm_name, "id" => id}) do
    with {:ok, %DeviceStatus{} = device_status} <- Device.get_device_status!(realm_name, id) do
      render(conn, "show.json", device_status: device_status)
    end
  end

  def update(%Plug.Conn{method: "PATCH"} = conn, %{"realm_name" => realm_name, "id" => id, "data" => data}) do
    # Here we handle merge/patch as described here https://tools.ietf.org/html/rfc7396
    if get_req_header(conn, "content-type") == ["application/merge-patch+json"] do
      with :ok <- Device.merge_device_status!(realm_name, id, data),
           {:ok, %DeviceStatus{} = device_status} <- Device.get_device_status!(realm_name, id) do
        render(conn, "show.json", device_status: device_status)
      end
    else
      {:error, :patch_mimetype_not_supported}
    end
  end
end
