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
defmodule Astarte.AppEngine.APIWeb.DeviceStatusByGroupController do
  use Astarte.AppEngine.APIWeb, :controller

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Groups
  alias Astarte.AppEngine.APIWeb.DeviceStatusView

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  def index(
        conn,
        %{"realm_name" => realm_name, "group_name" => group_name, "details" => "true"} = params
      ) do
    decoded_group_name = URI.decode(group_name)

    with {:ok, %DevicesList{} = devices_list} <-
           Groups.list_detailed_devices(realm_name, decoded_group_name, params) do
      render(conn, "detailed_index.json", devices_list: devices_list, request: params)
    end
  end

  def index(conn, %{"realm_name" => realm_name, "group_name" => group_name} = params) do
    decoded_group_name = URI.decode(group_name)

    with {:ok, %DevicesList{} = devices_list} <-
           Groups.list_devices(realm_name, decoded_group_name, params) do
      render(conn, "index.json", devices_list: devices_list, request: params)
    end
  end

  def show(conn, %{
        "realm_name" => realm_name,
        "group_name" => group_name,
        "device_id" => device_id
      }) do
    with {:ok, true} <- Groups.check_device_in_group(realm_name, group_name, device_id),
         {:ok, device_status} <- Device.get_device_status!(realm_name, device_id) do
      conn
      |> put_view(DeviceStatusView)
      |> render("show.json", device_status: device_status)
    else
      {:ok, false} ->
        {:error, :device_not_found}

      {:error, reason} ->
        # To FallbackController
        {:error, reason}
    end
  end

  def update(%Plug.Conn{method: "PATCH"} = conn, %{
        "realm_name" => realm_name,
        "group_name" => group_name,
        "device_id" => device_id,
        "data" => data
      }) do
    # Here we handle merge/patch as described here https://tools.ietf.org/html/rfc7396
    if get_req_header(conn, "content-type") == ["application/merge-patch+json"] do
      with {:ok, true} <- Groups.check_device_in_group(realm_name, group_name, device_id),
           {:ok, %DeviceStatus{} = device_status} <-
             Device.merge_device_status(realm_name, device_id, data) do
        conn
        |> put_view(DeviceStatusView)
        |> render("show.json", device_status: device_status)
      else
        {:ok, false} ->
          {:error, :device_not_found}

        {:error, reason} ->
          # To FallbackController
          {:error, reason}
      end
    else
      {:error, :patch_mimetype_not_supported}
    end
  end
end
