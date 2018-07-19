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
# Copyright (C) 2017-2018 Ispirata Srl
#

defmodule Astarte.RealmManagement.APIWeb.InterfaceController do
  use Astarte.RealmManagement.APIWeb, :controller

  alias Astarte.Core.Interface
  alias Astarte.RealmManagement.API.Interfaces

  action_fallback Astarte.RealmManagement.APIWeb.FallbackController

  plug Astarte.RealmManagement.APIWeb.Plug.AuthorizePath

  def index(conn, %{"realm_name" => realm_name}) do
    interfaces = Astarte.RealmManagement.API.Interfaces.list_interfaces!(realm_name)
    render(conn, "index.json", interfaces: interfaces)
  end

  def create(conn, %{"realm_name" => realm_name, "data" => %{} = params}) do
    with {:ok, %Interface{} = interface} <- Interfaces.create_interface(realm_name, params) do
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

      {:error, :invalid_name_casing = err_atom} ->
        conn
        |> put_status(:conflict)
        |> render(err_atom)

      # Let FallbackController handle the rest
      {:error, other} ->
        {:error, other}
    end
  end

  def show(conn, %{"realm_name" => realm_name, "id" => id, "major_version" => major_version}) do
    {parsed_major, ""} = Integer.parse(major_version)

    interface_source = Interfaces.get_interface!(realm_name, id, parsed_major)

    {:ok, decoded_json} = Poison.decode(interface_source)
    render(conn, "show.json", interface: decoded_json)
  end

  def update(conn, %{
        "realm_name" => realm_name,
        "id" => interface_name,
        "major_version" => major_version,
        "data" => %{} = params
      }) do
    with {:major_parsing, {parsed_major, ""}} <- {:major_parsing, Integer.parse(major_version)},
         {:ok, :started} <-
           Interfaces.update_interface(realm_name, interface_name, parsed_major, params) do
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

  def delete(conn, %{
        "realm_name" => realm_name,
        "id" => interface_name,
        "major_version" => major_version
      }) do
    {parsed_major, ""} = Integer.parse(major_version)

    with {:ok, :started} <-
           Interfaces.delete_interface!(
             realm_name,
             interface_name,
             parsed_major
           ) do
      send_resp(conn, :no_content, "")
    end
  end
end
