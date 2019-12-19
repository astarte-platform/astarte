#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.AppEngine.APIWeb.DeviceStatusByAliasController do
  use Astarte.AppEngine.APIWeb, :controller

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.APIWeb.DeviceStatusView

  plug Astarte.AppEngine.APIWeb.Plug.AuthorizePath

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  # TODO: should we allow to POST/create device aliases here by posting something like a DeviceAlias JSON object?
  # def create(conn, %{"device_status_by_alias" => device_status_by_alias_params})

  def index(_conn, _params) do
    {:error, :devices_listing_by_alias_not_allowed}
  end

  def show(conn, %{"realm_name" => realm_name, "id" => device_alias}) do
    with {:ok, device_id} <- Device.device_alias_to_device_id(realm_name, device_alias),
         encoded_device_id <- Base.url_encode64(device_id, padding: false),
         {:ok, device_status_by_alias} <- Device.get_device_status!(realm_name, encoded_device_id) do
      render(conn, DeviceStatusView, "show.json", device_status: device_status_by_alias)
    end
  end

  def update(%Plug.Conn{method: "PATCH"} = conn, %{
        "realm_name" => realm_name,
        "id" => device_alias,
        "data" => data
      }) do
    # Here we handle merge/patch as described here https://tools.ietf.org/html/rfc7396
    if get_req_header(conn, "content-type") == ["application/merge-patch+json"] do
      with {:ok, device_id} <- Device.device_alias_to_device_id(realm_name, device_alias),
           encoded_device_id <- Base.url_encode64(device_id, padding: false),
           :ok <- Device.merge_device_status!(realm_name, encoded_device_id, data),
           {:ok, %DeviceStatus{} = device_status} <-
             Device.get_device_status!(realm_name, encoded_device_id) do
        render(conn, DeviceStatusView, "show.json", device_status: device_status)
      end
    else
      {:error, :patch_mimetype_not_supported}
    end
  end
end
