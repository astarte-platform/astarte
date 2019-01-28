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
