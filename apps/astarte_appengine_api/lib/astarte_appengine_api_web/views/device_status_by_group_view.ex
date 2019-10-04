#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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
#

defmodule Astarte.AppEngine.APIWeb.DeviceStatusByGroupView do
  use Astarte.AppEngine.APIWeb, :view
  alias Astarte.AppEngine.APIWeb.Endpoint
  alias Astarte.AppEngine.APIWeb.DeviceStatusView
  alias Astarte.AppEngine.APIWeb.Router.Helpers, as: RouterHelpers

  def render("index.json", %{devices_list: devices_list, request: params}) do
    %{
      links: build_links(params, devices_list.last_token),
      data: devices_list.devices
    }
  end

  def render("detailed_index.json", %{devices_list: devices_list, request: params}) do
    %{
      links: build_links(params, devices_list.last_token),
      data: render_many(devices_list.devices, DeviceStatusView, "device_status.json")
    }
  end

  defp build_links(%{"realm_name" => realm, "group_name" => group} = params, last_token) do
    request_params = Map.take(params, ["limit", "details", "from_token"])

    self_path =
      RouterHelpers.device_status_by_group_path(Endpoint, :index, realm, group, request_params)

    if last_token do
      next_params = Map.put(request_params, "from_token", last_token)

      next_path =
        RouterHelpers.device_status_by_group_path(Endpoint, :index, realm, group, next_params)

      %{self: self_path, next: next_path}
    else
      %{self: self_path}
    end
  end
end
