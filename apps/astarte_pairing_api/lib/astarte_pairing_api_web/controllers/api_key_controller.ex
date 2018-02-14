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

defmodule Astarte.Pairing.APIWeb.APIKeyController do
  use Astarte.Pairing.APIWeb, :controller

  alias Astarte.Pairing.API.Agent
  alias Astarte.Pairing.API.Agent.APIKey
  alias Astarte.Pairing.API.Agent.Realm
  alias Astarte.Pairing.APIWeb.AgentGuardian

  plug Guardian.Plug.Pipeline,
    otp_app: :astarte_pairing_api,
    module: Astarte.Pairing.APIWeb.AgentGuardian,
    error_handler: Astarte.Pairing.APIWeb.FallbackController
  plug Guardian.Plug.VerifyHeader, realm: :none
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource

  action_fallback Astarte.Pairing.APIWeb.FallbackController

  def create(conn, %{"hwId" => hw_id}) do
    # hwId is spelled this way to preserve backwards compatibility
    with %Realm{realm_name: realm} <- AgentGuardian.Plug.current_resource(conn),
         {:ok, %APIKey{} = api_key} <- Agent.generate_api_key(%{"hw_id" => hw_id, "realm" => realm}) do
      conn
      |> put_status(:created)
      |> render("show.json", api_key)
    end
  end
end
