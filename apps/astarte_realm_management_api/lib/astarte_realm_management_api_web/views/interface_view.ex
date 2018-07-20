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

defmodule Astarte.RealmManagement.APIWeb.InterfaceView do
  use Astarte.RealmManagement.APIWeb, :view

  def render("index.json", %{interfaces: interfaces}) do
    %{data: interfaces}
  end

  def render("show.json", %{interface: interface}) do
    %{data: interface}
  end

  def render("already_installed_interface.json", _assigns) do
    %{errors: %{detail: "Interface already exists"}}
  end

  def render("invalid_name_casing.json", _assigns) do
    %{errors: %{detail: "Interface already exists with a different casing name"}}
  end

  def render("name_not_matching.json", _assigns) do
    %{errors: %{detail: "Interface name doesn't match the one in the interface json"}}
  end

  def render("major_version_not_matching.json", _assigns) do
    %{errors: %{detail: "Interface major version doesn't match the one in the interface json"}}
  end

  def render("interface_major_version_does_not_exist.json", _assigns) do
    %{errors: %{detail: "Interface major not found"}}
  end

  def render("minor_version_not_increased.json", _assigns) do
    %{errors: %{detail: "Interface minor version was not increased"}}
  end

  def render("invalid_update.json", _assigns) do
    %{errors: %{detail: "Invalid update"}}
  end

  def render("downgrade_not_allowed.json", _assigns) do
    %{errors: %{detail: "Interface downgrade not allowed"}}
  end

  def render("missing_endpoints.json", _assigns) do
    %{errors: %{detail: "Interface update has missing endpoints"}}
  end

  def render("incompatible_endpoint_change.json", _assigns) do
    %{errors: %{detail: "Interface update contains incompatible endpoint changes"}}
  end
end
