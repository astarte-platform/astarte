# Copyright 2019-2024 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule Astarte.AppEngine.APIWeb.InterfaceValuesByGroupController do
  use Astarte.AppEngine.APIWeb, :controller

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.AppEngine.API.Groups
  alias Astarte.AppEngine.APIWeb.InterfaceValuesView

  action_fallback Astarte.AppEngine.APIWeb.FallbackController

  def index(conn, %{
        "realm_name" => realm_name,
        "group_name" => group_name,
        "device_id" => device_id
      }) do
    with {:ok, true} <- Groups.check_device_in_group(realm_name, group_name, device_id),
         {:ok, interfaces} <- Device.list_interfaces(realm_name, device_id) do
      conn
      |> put_view(InterfaceValuesView)
      |> render("index.json", interfaces: interfaces)
    else
      {:ok, false} ->
        {:error, :device_not_found}

      {:error, reason} ->
        # To FallbackController
        {:error, reason}
    end
  end

  def show(
        conn,
        %{
          "realm_name" => realm_name,
          "group_name" => group_name,
          "device_id" => device_id,
          "interface" => interface,
          "path" => path
        } = parameters
      ) do
    with {:ok, true} <- Groups.check_device_in_group(realm_name, group_name, device_id),
         {:ok, %InterfaceValues{} = interface_values} <-
           Device.get_interface_values!(
             realm_name,
             device_id,
             interface,
             path,
             parameters
           ) do
      conn
      |> put_view(InterfaceValuesView)
      |> render("show.json", interface_values: interface_values)
    else
      {:ok, false} ->
        {:error, :device_not_found}

      {:error, reason} ->
        # To FallbackController
        {:error, reason}
    end
  end

  def show(
        conn,
        %{
          "realm_name" => realm_name,
          "group_name" => group_name,
          "device_id" => device_id,
          "interface" => interface
        } = parameters
      ) do
    with {:ok, true} <- Groups.check_device_in_group(realm_name, group_name, device_id),
         {:ok, %InterfaceValues{} = interface_values} <-
           Device.get_interface_values!(realm_name, device_id, interface, parameters) do
      conn
      |> put_view(InterfaceValuesView)
      |> render("show.json", interface_values: interface_values)
    else
      {:ok, false} ->
        {:error, :device_not_found}

      {:error, reason} ->
        # To FallbackController
        {:error, reason}
    end
  end

  def update(
        conn,
        %{
          "realm_name" => realm_name,
          "group_name" => group_name,
          "device_id" => device_id,
          "interface" => interface,
          "path" => path,
          "data" => value
        } = parameters
      ) do
    with {:ok, true} <- Groups.check_device_in_group(realm_name, group_name, device_id),
         {:ok, %InterfaceValues{} = interface_values} <-
           Device.update_interface_values(
             realm_name,
             device_id,
             interface,
             path,
             value,
             parameters
           ) do
      conn
      |> put_view(InterfaceValuesView)
      |> render("show.json", interface_values: interface_values)
    else
      {:ok, false} ->
        {:error, :device_not_found}

      {:error, reason} ->
        # To FallbackController
        {:error, reason}
    end
  end

  def delete(conn, %{
        "realm_name" => realm_name,
        "group_name" => group_name,
        "device_id" => device_id,
        "interface" => interface,
        "path" => path
      }) do
    with {:ok, true} <- Groups.check_device_in_group(realm_name, group_name, device_id),
         :ok <- Device.delete_interface_values(realm_name, device_id, interface, path) do
      send_resp(conn, :no_content, "")
    else
      {:ok, false} ->
        {:error, :device_not_found}

      {:error, reason} ->
        # To FallbackController
        {:error, reason}
    end
  end
end
