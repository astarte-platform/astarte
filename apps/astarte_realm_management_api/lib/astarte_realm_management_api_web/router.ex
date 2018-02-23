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

defmodule Astarte.RealmManagement.APIWeb.Router do
  use Astarte.RealmManagement.APIWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/v1", Astarte.RealmManagement.APIWeb do
    pipe_through :api

    get "/:realm_name/interfaces/:id", InterfaceVersionController, :index
    resources "/:realm_name/interfaces", InterfaceController, only: [:index, :create]
    get "/:realm_name/interfaces/:id/:major_version", InterfaceController, :show
    put "/:realm_name/interfaces/:id/:major_version", InterfaceController, :update
    delete "/:realm_name/interfaces/:id/:major_version", InterfaceController, :delete
    get "/:realm_name/config/:group", RealmConfigController, :show
    put "/:realm_name/config/:group", RealmConfigController, :update

    resources "/triggers", TriggerController, except: [:new, :edit]
  end
end
