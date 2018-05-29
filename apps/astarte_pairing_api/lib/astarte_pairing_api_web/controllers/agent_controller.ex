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

defmodule Astarte.Pairing.APIWeb.AgentController do
  use Astarte.Pairing.APIWeb, :controller

  alias Astarte.Pairing.API.Agent
  alias Astarte.Pairing.API.Agent.DeviceRegistrationResponse

  action_fallback Astarte.Pairing.APIWeb.FallbackController

  plug Astarte.Pairing.APIWeb.Plug.AuthorizePath

  def create(conn, %{"realm_name" => realm, "data" => params}) do
    with {:ok, %DeviceRegistrationResponse{} = response} <- Agent.register_device(realm, params) do
      conn
      |> put_status(:created)
      |> render("show.json", device_registration_response: response)
    end
  end
end
