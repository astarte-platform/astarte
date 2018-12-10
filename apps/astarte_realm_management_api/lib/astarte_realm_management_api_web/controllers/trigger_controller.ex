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

defmodule Astarte.RealmManagement.APIWeb.TriggerController do
  use Astarte.RealmManagement.APIWeb, :controller

  alias Astarte.RealmManagement.API.Triggers
  alias Astarte.RealmManagement.API.Triggers.Trigger

  action_fallback Astarte.RealmManagement.APIWeb.FallbackController

  plug Astarte.RealmManagement.APIWeb.Plug.AuthorizePath

  def index(conn, %{"realm_name" => realm_name}) do
    triggers = Triggers.list_triggers(realm_name)
    render(conn, "index.json", triggers: triggers)
  end

  def create(conn, %{"realm_name" => realm_name, "data" => trigger_params}) do
    with {:ok, %Trigger{} = trigger} <- Triggers.create_trigger(realm_name, trigger_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", trigger_path(conn, :show, realm_name, trigger))
      |> render("show.json", trigger: trigger)
    else
      {:error, :already_installed_trigger} ->
        conn
        |> put_status(:conflict)
        |> render("show.json", error: :already_installed_trigger)

      # To FallbackController
      {:error, other} ->
        {:error, other}
    end
  end

  def show(conn, %{"realm_name" => realm_name, "id" => id}) do
    with {:ok, trigger} <- Triggers.get_trigger(realm_name, id) do
      render(conn, "show.json", trigger: trigger)
    end
  end

  def update(conn, %{"realm_name" => realm_name, "id" => id, "data" => trigger_params}) do
    with {:ok, trigger} <- Triggers.get_trigger(realm_name, id),
         {:ok, %Trigger{} = updated_trigger} <-
           Triggers.update_trigger(
             realm_name,
             trigger,
             trigger_params
           ) do
      render(conn, "show.json", trigger: updated_trigger)
    end
  end

  def delete(conn, %{"realm_name" => realm_name, "id" => id}) do
    with {:ok, %Trigger{} = trigger} <- Triggers.get_trigger(realm_name, id),
         {:ok, %Trigger{}} <- Triggers.delete_trigger(realm_name, trigger) do
      send_resp(conn, :no_content, "")
    end
  end
end
