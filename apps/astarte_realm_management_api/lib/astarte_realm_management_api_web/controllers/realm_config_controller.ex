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

defmodule Astarte.RealmManagement.APIWeb.RealmConfigController do
  use Astarte.RealmManagement.APIWeb, :controller

  alias Astarte.RealmManagement.API.RealmConfig
  alias Astarte.RealmManagement.API.RealmConfig.AuthConfig

  action_fallback Astarte.RealmManagement.APIWeb.FallbackController

  plug Astarte.RealmManagement.APIWeb.Plug.AuthorizePath

  def show(conn, %{"realm_name" => realm_name, "group" => "auth"}) do
    with {:ok, %AuthConfig{} = auth_config} = RealmConfig.get_auth_config(realm_name) do
      render(conn, "show.json", auth_config: auth_config)
    end
  end

  def update(conn, %{"realm_name" => realm_name, "group" => "auth", "data" => new_config}) do
    with :ok <- RealmConfig.update_auth_config(realm_name, new_config) do
      send_resp(conn, :no_content, "")
    end
  end
end
