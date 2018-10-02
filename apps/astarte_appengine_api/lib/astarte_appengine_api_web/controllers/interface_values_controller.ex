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

defmodule Astarte.AppEngine.APIWeb.InterfaceValuesController do
  use Astarte.AppEngine.APIWeb, :controller
  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.InterfaceValues

  plug Astarte.AppEngine.APIWeb.Plug.AuthorizePath

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  def index(conn, %{"realm_name" => realm_name, "device_id" => device_id}) do
    with {:ok, interfaces} <- Device.list_interfaces(realm_name, device_id) do
      render(conn, "index.json", interfaces: interfaces)
    end
  end

  def show(
        conn,
        %{"realm_name" => realm_name, "device_id" => device_id, "id" => interface, "path" => path} =
          parameters
      ) do
    with {:ok, %InterfaceValues{} = interface_values} <-
           Device.get_interface_values!(realm_name, device_id, interface, path, parameters) do
      render(conn, "show.json", interface_values: interface_values)
    end
  end

  def show(
        conn,
        %{"realm_name" => realm_name, "device_id" => device_id, "id" => interface} = parameters
      ) do
    with {:ok, %InterfaceValues{} = interface_values} <-
           Device.get_interface_values!(realm_name, device_id, interface, parameters) do
      render(conn, "show.json", interface_values: interface_values)
    end
  end

  def update(
        conn,
        %{
          "realm_name" => realm_name,
          "device_id" => device_id,
          "id" => interface,
          "path" => path,
          "data" => value
        } = parameters
      ) do
    with {:ok, %InterfaceValues{} = interface_values} <-
           Device.update_interface_values!(
             realm_name,
             device_id,
             interface,
             path,
             value,
             parameters
           ) do
      render(conn, "show.json", interface_values: interface_values)
    end
  end

  def delete(conn, %{
        "realm_name" => realm_name,
        "device_id" => device_id,
        "id" => interface,
        "path" => path
      }) do
    with :ok <- Device.delete_interface_values(realm_name, device_id, interface, path) do
      send_resp(conn, :no_content, "")
    end
  end
end
