#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Astarte.AppEngine.APIWeb.DeviceStatusView do
  use Astarte.AppEngine.APIWeb, :view
  alias Astarte.AppEngine.APIWeb.DeviceStatusView
  alias Astarte.AppEngine.APIWeb.Router.Helpers, as: RouterHelpers

  def render("index.json", %{
        devices_list: devices_list,
        request: %{"realm_name" => realm} = params
      }) do
    {request_params, _} = Map.split(params, ["limit", "details", "from_token"])

    last_token = devices_list.last_token

    links =
      case last_token do
        nil ->
          %{self: RouterHelpers.device_status_path(%URI{}, :index, realm, request_params)}

        last_token ->
          next_request_params = Map.put(request_params, "from_token", last_token)

          %{
            self: RouterHelpers.device_status_path(%URI{}, :index, realm, request_params),
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