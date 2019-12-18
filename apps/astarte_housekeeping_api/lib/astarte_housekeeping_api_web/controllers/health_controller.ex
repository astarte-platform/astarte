#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
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
