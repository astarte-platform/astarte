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

defmodule Astarte.Pairing.APIWeb.Router do
  use Astarte.Pairing.APIWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/v1", Astarte.Pairing.APIWeb do
    pipe_through :api

    post "/:realm_name/agent/devices", AgentController, :create

    get "/:realm_name/devices/:hw_id", DeviceController, :show_info

    post "/:realm_name/devices/:hw_id/protocols/:protocol/credentials",
         DeviceController,
         :create_credentials

    post "/:realm_name/devices/:hw_id/protocols/:protocol/credentials/verify",
         DeviceController,
         :verify_credentials
  end
end
