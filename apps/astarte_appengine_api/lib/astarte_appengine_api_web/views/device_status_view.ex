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

defmodule Astarte.AppEngine.APIWeb.DeviceStatusView do
  use Astarte.AppEngine.APIWeb, :view
  alias Astarte.AppEngine.APIWeb.DeviceStatusView
  alias Astarte.AppEngine.APIWeb.Router.Helpers, as: RouterHelpers

  def render("index.json", %{devices_list: devices_list, request: %{"realm_name" => realm} = params}) do
    {request_params, _} = Map.split(params, ["limit", "details", "from_token"])

    last_token = devices_list.last_token

    links =
      case last_token do
        nil ->
          %{"self": RouterHelpers.device_status_path(%URI{}, :index, realm, request_params)}

        last_token ->
          next_request_params = Map.put(request_params, "from_token", last_token)
          %{
            "self": RouterHelpers.device_status_path(%URI{}, :index, realm, request_params),
            next: RouterHelpers.device_status_path(%URI{}, :index, realm, next_request_params)
          }
      end

    %{
      links: links,
      data: devices_list.devices
    }
  end

  def render("index.json", %{devices: devices}) do
    %{data: render_many(devices, DeviceStatusView, "device_status.json")}
  end

  def render("show.json", %{device_status: device_status}) do
    %{data: render_one(device_status, DeviceStatusView, "device_status.json")}
  end

  def render("device_status.json", %{device_status: device_status}) do
    device_status
  end
end
