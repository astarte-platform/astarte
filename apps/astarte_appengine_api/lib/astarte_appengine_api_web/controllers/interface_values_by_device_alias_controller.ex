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
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.AppEngine.APIWeb.InterfaceValuesView
  alias CQEx.Client, as: DatabaseClient

  plug Astarte.AppEngine.APIWeb.Plug.AuthorizePath

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  def index(conn, %{"realm_name" => realm_name, "device_alias" => device_alias}) do
    with {:ok, client} <- DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]),
         {:ok, device_id} <- Device.device_alias_to_device_id(client, device_alias) do
      encoded_device_id = Base.url_encode64(device_id, padding: false)
      interfaces_by_device_alias = Device.list_interfaces!(realm_name, encoded_device_id)
      render(conn, InterfaceValuesView, "index.json", interfaces: interfaces_by_device_alias)
    end
  end

  def show(conn, %{"realm_name" => realm_name, "device_alias" => device_alias, "id" => interface, "path" => path} = parameters) do
    with {:ok, client} <- DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]),
         {:ok, device_id} <- Device.device_alias_to_device_id(client, device_alias),
         encoded_device_id <- Base.url_encode64(device_id, padding: false),
         {:ok, %InterfaceValues{} = interface_values} <- Device.get_interface_values!(realm_name, encoded_device_id, interface, path, parameters) do
      render(conn, InterfaceValuesView, "show.json", interface_values: interface_values)
    end
  end

  def show(conn, %{"realm_name" => realm_name, "device_alias" => device_alias, "id" => interface} = parameters) do
    with {:ok, client} <- DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]),
         {:ok, device_id} <- Device.device_alias_to_device_id(client, device_alias),
         encoded_device_id <- Base.url_encode64(device_id, padding: false),
         {:ok, %InterfaceValues{} = interface_values} <- Device.get_interface_values!(realm_name, encoded_device_id, interface, parameters) do
      render(conn, InterfaceValuesView, "show.json", interface_values: interface_values)
    end
  end

  def update(conn, %{"realm_name" => realm_name, "device_alias" => device_alias, "id" => interface, "path" => path, "value" => value} = parameters) do
    with {:ok, client} <- DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]),
         {:ok, device_id} <- Device.device_alias_to_device_id(client, device_alias),
         encoded_device_id <- Base.url_encode64(device_id, padding: false),
         {:ok, %InterfaceValues{} = interface_values} <- Device.update_interface_values!(realm_name, encoded_device_id, interface, path, value, parameters) do
      render(conn, InterfaceValuesView, "show.json", interface_values: interface_values)
    end
  end
end
