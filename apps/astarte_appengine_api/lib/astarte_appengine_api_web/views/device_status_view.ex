# Copyright 2017-2023 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

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
  alias Astarte.AppEngine.API.Device.InterfaceInfo
  alias Astarte.AppEngine.APIWeb.DeviceStatusView
  alias Astarte.AppEngine.APIWeb.Router.Helpers, as: RouterHelpers

  def render("index.json", %{devices_list: devices_list, request: params}) do
    %{
      links: build_links(params, devices_list.last_token),
      data: render_many(devices_list.devices, DeviceStatusView, "device_id.json", as: :device_id)
    }
  end

  def render("detailed_index.json", %{devices_list: devices_list, request: params}) do
    %{
      links: build_links(params, devices_list.last_token),
      data: render_many(devices_list.devices, DeviceStatusView, "device_status.json")
    }
  end

  def render("index.json", %{devices: devices}) do
    %{data: render_many(devices, DeviceStatusView, "device_status.json")}
  end

  def render("show.json", %{device_status: device_status}) do
    %{data: render_one(device_status, DeviceStatusView, "device_status.json")}
  end

  def render("device_status.json", %{device_status: device_status}) do
    %{
      id: device_status.id,
      connected: device_status.connected || false,
      introspection:
        render_one(device_status.introspection, DeviceStatusView, "introspection.json",
          as: :introspection
        ),
      total_received_msgs: device_status.total_received_msgs,
      total_received_bytes: device_status.total_received_bytes,
      last_connection: device_status.last_connection,
      last_disconnection: device_status.last_disconnection,
      last_seen_ip: device_status.last_seen_ip,
      last_credentials_request_ip: device_status.last_credentials_request_ip,
      credentials_inhibited: device_status.credentials_inhibited,
      first_registration: device_status.first_registration,
      first_credentials_request: device_status.first_credentials_request,
      aliases: device_status.aliases,
      attributes: device_status.attributes,
      groups: device_status.groups,
      previous_interfaces:
        render_many(device_status.previous_interfaces, DeviceStatusView, "interface_info.json",
          as: :interface_info
        ),
      deletion_in_progress: device_status.deletion_in_progress
    }
  end

  def render("device_id.json", %{device_id: device_id}) do
    device_id
  end

  def render("introspection.json", %{introspection: introspection}) do
    for {interface_name, %InterfaceInfo{} = info} <- introspection, into: %{} do
      info_map = %{
        minor: info.minor,
        major: info.major,
        exchanged_msgs: info.exchanged_msgs,
        exchanged_bytes: info.exchanged_bytes
      }

      {interface_name, info_map}
    end
  end

  def render("interface_info.json", %{interface_info: interface_info}) do
    %{
      name: interface_info.name,
      minor: interface_info.minor,
      major: interface_info.major,
      exchanged_msgs: interface_info.exchanged_msgs,
      exchanged_bytes: interface_info.exchanged_bytes
    }
  end

  defp build_links(%{"realm_name" => realm} = params, last_token) do
    {request_params, _} = Map.split(params, ["limit", "details", "from_token"])

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
  end
end
