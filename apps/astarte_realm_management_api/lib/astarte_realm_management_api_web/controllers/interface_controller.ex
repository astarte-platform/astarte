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

defmodule Astarte.RealmManagement.APIWeb.InterfaceController do
  use Astarte.RealmManagement.APIWeb, :controller

  alias Astarte.Core.Interface
  alias Astarte.RealmManagement.API.Interfaces

  action_fallback Astarte.RealmManagement.APIWeb.FallbackController

  def index(conn, %{"realm_name" => realm_name} = params) do
    detailed = Map.get(params, "detailed") == "true"

    with {:ok, interfaces} <- Interfaces.list_interfaces(realm_name, %{"detailed" => detailed}) do
      interface_list = if detailed, do: Enum.map(interfaces, &Jason.decode!/1), else: interfaces
      render(conn, "index.json", interfaces: interface_list)
    end
  end

  def create(conn, %{"realm_name" => realm_name, "data" => %{} = interface_params} = params) do
    async_operation =
      if Map.get(params, "async_operation") == "false" do
        false
      else
        true
      end

    with {:ok, %Interface{} = interface} <-
           Interfaces.create_interface(realm_name, interface_params,
             async_operation: async_operation
           ) do
      location =
        interface_path(
          conn,
          :show,
          realm_name,
          interface.name,
          Integer.to_string(interface.major_version)
        )

      conn
      |> put_resp_header("location", location)
      |> send_resp(:created, "")
    else
      {:error, :already_installed_interface = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      {:error, :interface_name_collision = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      # Let FallbackController handle the rest
      {:error, other} ->
        {:error, other}
    end
  end

  def show(conn, %{"realm_name" => realm_name, "id" => id, "major_version" => major_version}) do
    with {:major_parsing, {parsed_major, ""}} <- {:major_parsing, Integer.parse(major_version)},
         {:ok, interface_source} <- Interfaces.get_interface(realm_name, id, parsed_major),
         {:ok, decoded_json} <- Jason.decode(interface_source) do
      render(conn, "show.json", interface: decoded_json)
    else
      {:major_parsing, _} ->
        {:error, :invalid_major}

      # To FallbackController
      {:error, other} ->
        {:error, other}
    end
  end

  def update(
        conn,
        %{
          "realm_name" => realm_name,
          "id" => interface_name,
          "major_version" => major_version,
          "data" => %{} = interface_params
        } = params
      ) do
    async_operation =
      if Map.get(params, "async_operation") == "false" do
        false
      else
        true
      end

    with {:major_parsing, {parsed_major, ""}} <- {:major_parsing, Integer.parse(major_version)},
         :ok <-
           Interfaces.update_interface(realm_name, interface_name, parsed_major, interface_params,
             async_operation: async_operation
           ) do
      send_resp(conn, :no_content, "")
    else
      {:major_parsing, _} ->
        {:error, :invalid_major}

      # API side errors
      {:error, :name_not_matching = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      {:error, :major_version_not_matching = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      # Backend side errors
      {:error, :interface_major_version_does_not_exist = err_atom} ->
        conn
        |> put_status(:not_found)
        |> render(err_atom)

      {:error, :minor_version_not_increased = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      {:error, :invalid_update = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      {:error, :downgrade_not_allowed = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      {:error, :missing_endpoints = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      {:error, :incompatible_endpoint_change = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      # Let FallbackController handle the rest
      {:error, other} ->
        {:error, other}
    end
  end

  def delete(
        conn,
        %{
          "realm_name" => realm_name,
          "id" => interface_name,
          "major_version" => major_version
        } = params
      ) do
    {parsed_major, ""} = Integer.parse(major_version)

    async_operation =
      if Map.get(params, "async_operation") == "false" do
        false
      else
        true
      end

    with :ok <-
           Interfaces.delete_interface(
             realm_name,
             interface_name,
             parsed_major,
             async_operation: async_operation
           ) do
      send_resp(conn, :no_content, "")
    else
      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> render(:delete_forbidden)

      {:error, :cannot_delete_currently_used_interface = err_atom} ->
        conn
        |> put_status(:forbidden)
        |> render(err_atom)

      # To FallbackController
      {:error, other} ->
        {:error, other}
    end
  end
end
