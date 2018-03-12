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

defmodule Astarte.AppEngine.APIWeb.DeviceStatusByAliasView do
  use Astarte.AppEngine.APIWeb, :view
  alias Astarte.AppEngine.APIWeb.DeviceStatusByAliasView
  alias Astarte.AppEngine.APIWeb.DeviceStatusView

  def render("index.json", %{devices_by_alias: devices_by_alias}) do
    %{data: render_many(devices_by_alias, DeviceStatusByAliasView, "device_status_by_alias.json")}
  end

  def render("show.json", %{device_status_by_alias: device_status_by_alias}) do
    DeviceStatusView.render("show.json", %{device_status: device_status_by_alias})
  end

  def render("device_status_by_alias.json", %{device_status_by_alias: device_status_by_alias}) do
    %{id: device_status_by_alias.id}
  end
end
