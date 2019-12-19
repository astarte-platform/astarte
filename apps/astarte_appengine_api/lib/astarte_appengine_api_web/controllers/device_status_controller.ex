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

  def update(%Plug.Conn{method: "PATCH"} = conn, %{
        "realm_name" => realm_name,
        "id" => id,
        "data" => data
      }) do
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
