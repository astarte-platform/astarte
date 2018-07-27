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

defmodule Astarte.Housekeeping.APIWeb.RealmController do
  use Astarte.Housekeeping.APIWeb, :controller

  alias Astarte.Housekeeping.API.Realms
  alias Astarte.Housekeeping.API.Realms.Realm

  action_fallback Astarte.Housekeeping.APIWeb.FallbackController

  plug Astarte.Housekeeping.APIWeb.Plug.AuthorizePath

  def index(conn, _params) do
    realms = Realms.list_realms()
    render(conn, "index.json", realms: realms)
  end

  def create(conn, %{ "data" => realm_params}) do
    with {:ok, %Realm{} = realm} <- Realms.create_realm(realm_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", realm_path(conn, :show, realm))
      |> render("show.json", realm: realm)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, %Realm{} = realm} <- Realms.get_realm(id) do
      render(conn, "show.json", realm: realm)
    end
  end

  def update(conn, %{"id" => id, "data" => realm_params}) do
    with {:ok, %Realm{} = realm} <- Realms.get_realm(id),
         {:ok, %Realm{} = realm} <- Realms.update_realm(realm, realm_params) do

      render(conn, "show.json", realm: realm)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, %Realm{} = realm} <- Realms.get_realm(id),
         {:ok, %Realm{}} <- Realms.delete_realm(realm) do

      send_resp(conn, :no_content, "")
    end
  end
end
