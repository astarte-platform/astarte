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

  def index(conn, _params) do
    triggers = RealmManagement.API.Triggers.list_triggers()
    render(conn, "index.json", triggers: triggers)
  end

  def create(conn, %{"trigger" => trigger_params}) do
    with {:ok, %Trigger{} = trigger} <- RealmManagement.API.Triggers.create_trigger(trigger_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", trigger_path(conn, :show, trigger))
      |> render("show.json", trigger: trigger)
    end
  end

  def show(conn, %{"id" => id}) do
    trigger = RealmManagement.API.Triggers.get_trigger!(id)
    render(conn, "show.json", trigger: trigger)
  end

  def update(conn, %{"id" => id, "trigger" => trigger_params}) do
    trigger = RealmManagement.API.Triggers.get_trigger!(id)

    with {:ok, %Trigger{} = trigger} <- RealmManagement.API.Triggers.update_trigger(trigger, trigger_params) do
      render(conn, "show.json", trigger: trigger)
    end
  end

  def delete(conn, %{"id" => id}) do
    trigger = RealmManagement.API.Triggers.get_trigger!(id)
    with {:ok, %Trigger{}} <- RealmManagement.API.Triggers.delete_trigger(trigger) do
      send_resp(conn, :no_content, "")
    end
  end
end
