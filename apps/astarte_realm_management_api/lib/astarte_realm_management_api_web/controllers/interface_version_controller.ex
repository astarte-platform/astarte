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

defmodule Astarte.RealmManagement.APIWeb.InterfaceVersionController do
  use Astarte.RealmManagement.APIWeb, :controller

  plug Astarte.RealmManagement.APIWeb.Plug.AuthorizePath

  action_fallback Astarte.RealmManagement.APIWeb.FallbackController

  def index(conn, %{"realm_name" => realm_name, "id" => id}) do
    interfaces = Astarte.RealmManagement.API.Interfaces.list_interface_major_versions!(realm_name, id)
    render(conn, "index.json", interfaces: interfaces)
  end

end
