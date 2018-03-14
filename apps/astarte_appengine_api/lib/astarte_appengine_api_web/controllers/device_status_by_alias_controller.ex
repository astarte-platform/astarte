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
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.AppEngine.APIWeb.DeviceStatusByAliasController do
  use Astarte.AppEngine.APIWeb, :controller

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.APIWeb.DeviceStatusView
  alias CQEx.Client, as: DatabaseClient

  plug Astarte.AppEngine.APIWeb.Plug.AuthorizePath

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  # TODO: should we allow to POST/create device aliases here by posting something like a DeviceAlias JSON object?
  # def create(conn, %{"device_status_by_alias" => device_status_by_alias_params})

  def index(_conn, _params) do
    {:error, :devices_listing_by_alias_not_allowed}
  end

  def show(conn, %{"realm_name" => realm_name, "id" => device_alias}) do
    with {:ok, client} <- DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]),
         {:ok, device_id} <- Device.device_alias_to_device_id(client, device_alias),
         encoded_device_id <- Base.url_encode64(device_id, padding: false),
         {:ok, device_status_by_alias} <- Device.get_device_status!(realm_name, encoded_device_id) do
      render(conn, DeviceStatusView, "show.json", device_status: device_status_by_alias)
    end
  end

  def update(%Plug.Conn{method: "PATCH"} = conn, %{"realm_name" => realm_name, "id" => device_alias, "data" => data}) do
    # Here we handle merge/patch as described here https://tools.ietf.org/html/rfc7396
    if get_req_header(conn, "content-type") == ["application/merge-patch+json"] do
      with {:ok, client} <- DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]),
           {:ok, device_id} <- Device.device_alias_to_device_id(client, device_alias),
           encoded_device_id <- Base.url_encode64(device_id, padding: false),
           :ok <- Device.merge_device_status!(realm_name, encoded_device_id, data),
           {:ok, %DeviceStatus{} = device_status} <- Device.get_device_status!(realm_name, encoded_device_id) do
        render(conn, DeviceStatusView, "show.json", device_status: device_status)
      end
    else
      {:error, :patch_mimetype_not_supported}
    end
  end
end
