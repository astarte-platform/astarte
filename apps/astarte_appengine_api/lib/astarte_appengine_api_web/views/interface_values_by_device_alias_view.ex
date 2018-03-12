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

defmodule Astarte.AppEngine.APIWeb.InterfaceValuesByDeviceAliasView do
  use Astarte.AppEngine.APIWeb, :view
  alias Astarte.AppEngine.APIWeb.InterfaceValuesByDeviceAliasView

  def render("index.json", %{interfaces_by_device_alias: interfaces_by_device_alias}) do
    %{data: render_many(interfaces_by_device_alias, InterfaceValuesByDeviceAliasView, "interface_values_by_device_alias.json")}
  end

  def render("show.json", %{interface_values_by_device_alias: interface_values_by_device_alias}) do
    %{data: render_one(interface_values_by_device_alias, InterfaceValuesByDeviceAliasView, "interface_values_by_device_alias.json")}
  end

  def render("interface_values_by_device_alias.json", %{interface_values_by_device_alias: interface_values_by_device_alias}) do
    %{id: interface_values_by_device_alias.id}
  end
end
