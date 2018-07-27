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

defmodule Astarte.Housekeeping.APIWeb.HealthController do
  use Astarte.Housekeeping.APIWeb, :controller

  alias Astarte.Housekeeping.API.Health
  alias Astarte.Housekeeping.API.Health.BackendHealth

  action_fallback Astarte.Housekeeping.APIWeb.FallbackController

  def show(conn, _params) do
    with {:ok, %BackendHealth{status: status} = backend_health} <- Health.get_backend_health() do
      conn =
        case status do
          :ready ->
            put_status(conn, :ok)
          :degraded ->
            # Some Cassandra nodes are available so it's still ok
            put_status(conn, :ok)
          :bad ->
            put_status(conn, :unavailable)
          :error ->
            put_status(conn, :unavailable)
        end

      render(conn, "show.json", backend_health: backend_health)
    end
  end
end
