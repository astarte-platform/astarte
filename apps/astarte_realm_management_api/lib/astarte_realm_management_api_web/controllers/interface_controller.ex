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

defmodule Astarte.RealmManagement.APIWeb.InterfaceController do
  use Astarte.RealmManagement.APIWeb, :controller

  action_fallback Astarte.RealmManagement.APIWeb.FallbackController

  def index(conn, %{"realm_name" => realm_name}) do
    interfaces = Astarte.RealmManagement.API.Interfaces.list_interfaces!(realm_name)
    render(conn, "index.json", interfaces: interfaces)
  end

  def create(conn, %{"realm_name" => realm_name, "data" => data}) do
    interface_source =
      cond do
        is_bitstring(data) ->
          data

        is_map(data) ->
          Poison.encode!(data, pretty: true)
      end

    case Astarte.Core.InterfaceDocument.from_json(interface_source) do
      :error ->
        {:error, :invalid}

      {:ok, doc} ->

        with {:ok, :started} <- Astarte.RealmManagement.API.Interfaces.create_interface!(realm_name, interface_source) do
          conn
          |> put_resp_header("location", interface_path(conn, :show, realm_name, doc.descriptor.name, Integer.to_string(doc.descriptor.major_version)))
          |> send_resp(:created, "")
        end
    end
  end

  def show(conn, %{"realm_name" => realm_name, "id" => id, "major_version" => major_version}) do
    {parsed_major, ""} = Integer.parse(major_version)
    interface_source = Astarte.RealmManagement.API.Interfaces.get_interface!(realm_name, id, parsed_major)

    # do not use render here, just return a raw json, render would escape this and ecapsulate it inside an outer JSON object
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, interface_source)
  end

  def update(conn, %{"realm_name" => realm_name, "id" => interface_name, "major_version" => major_version, "data" => interface_source}) do
    doc_result = Astarte.Core.InterfaceDocument.from_json(interface_source)

    cond do
      doc_result == :error ->
        {:error, :invalid}

      elem(doc_result, 1).descriptor.name != interface_name ->
        {:error, :conflict}

      {elem(doc_result, 1).descriptor.major_version, ""} != Integer.parse(major_version) ->
        {:error, :conflict}

      true ->
        with {:ok, :started} <- Astarte.RealmManagement.API.Interfaces.update_interface!(realm_name, interface_source) do
          send_resp(conn, :no_content, "")
        end
    end
  end

  def delete(conn, %{"realm_name" => realm_name, "id" => interface_name, "major_version" => major_version}) do
    {parsed_major, ""} = Integer.parse(major_version)

    with {:ok, :started} <- Astarte.RealmManagement.API.Interfaces.delete_interface!(realm_name, interface_name, parsed_major) do
      send_resp(conn, :no_content, "")
    end
  end
end
