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

defmodule Astarte.AppEngine.APIWeb.InterfaceValuesView do
  use Astarte.AppEngine.APIWeb, :view
  alias Astarte.AppEngine.APIWeb.InterfaceValuesView

  def render("index.json", %{interfaces: interfaces}) do
    %{data: render_many(interfaces, InterfaceValuesView, "interface_values.json")}
  end

  def render("show.json", %{interface_values: interface_values}) do
    %{data: render_one(interface_values, InterfaceValuesView, "interface_values.json")}
  end

  def render("interface_values.json", %{interface_values: interface_values}) do
    interface_values
  end
end
