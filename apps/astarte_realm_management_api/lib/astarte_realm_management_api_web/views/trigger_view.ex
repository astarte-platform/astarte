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

defmodule Astarte.RealmManagement.APIWeb.TriggerView do
  use Astarte.RealmManagement.APIWeb, :view
  alias Astarte.RealmManagement.APIWeb.TriggerView

  def render("index.json", %{triggers: triggers}) do
    %{data: render_many(triggers, TriggerView, "trigger_name_only.json")}
  end

  def render("show.json", %{trigger: trigger}) do
    %{data: render_one(trigger, TriggerView, "trigger.json")}
  end

  def render("trigger.json", %{trigger: trigger}) do
    %{id: trigger.id}
  end

  def render("trigger_name_only.json", %{trigger: trigger}) do
    trigger
  end

end
