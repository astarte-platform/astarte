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

defmodule Astarte.AppEngine.APIWeb.InterfaceValuesByDeviceAliasController do
  use Astarte.AppEngine.APIWeb, :controller

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.InterfaceValuesByDeviceAlias

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  def index(conn, _params) do
    interfaces_by_device_alias = AppEngine.API.Device.list_interfaces_by_device_alias()
    render(conn, "index.json", interfaces_by_device_alias: interfaces_by_device_alias)
  end

  def create(conn, %{"interface_values_by_device_alias" => interface_values_by_device_alias_params}) do
    with {:ok, %InterfaceValuesByDeviceAlias{} = interface_values_by_device_alias} <- AppEngine.API.Device.create_interface_values_by_device_alias(interface_values_by_device_alias_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", interface_values_by_device_alias_path(conn, :show, interface_values_by_device_alias))
      |> render("show.json", interface_values_by_device_alias: interface_values_by_device_alias)
    end
  end

  def show(conn, %{"id" => id}) do
    interface_values_by_device_alias = AppEngine.API.Device.get_interface_values_by_device_alias!(id)
    render(conn, "show.json", interface_values_by_device_alias: interface_values_by_device_alias)
  end

  def update(conn, %{"id" => id, "interface_values_by_device_alias" => interface_values_by_device_alias_params}) do
    interface_values_by_device_alias = AppEngine.API.Device.get_interface_values_by_device_alias!(id)

    with {:ok, %InterfaceValuesByDeviceAlias{} = interface_values_by_device_alias} <- AppEngine.API.Device.update_interface_values_by_device_alias(interface_values_by_device_alias, interface_values_by_device_alias_params) do
      render(conn, "show.json", interface_values_by_device_alias: interface_values_by_device_alias)
    end
  end

  def delete(conn, %{"id" => id}) do
    interface_values_by_device_alias = AppEngine.API.Device.get_interface_values_by_device_alias!(id)
    with {:ok, %InterfaceValuesByDeviceAlias{}} <- AppEngine.API.Device.delete_interface_values_by_device_alias(interface_values_by_device_alias) do
      send_resp(conn, :no_content, "")
    end
  end
end
