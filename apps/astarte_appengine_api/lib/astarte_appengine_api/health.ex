#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.AppEngine.API.Health do
  alias Astarte.AppEngine.API.Queries
  alias Astarte.DataAccess.Database
  alias Astarte.AppEngine.APIWeb.Metrics.HealthStatus

  def get_health do
    # TODO: the HealthStatus metrics gets set only when this call is made
    # (e.g. from Kubernetes readiness probe), so for now we have to
    # make sure that this gets called regularly or the health gauge won't
    # get updated
    with {:ok, client} <- Database.connect(),
         :ok <- Queries.check_astarte_health(client, :local_quorum) do
      HealthStatus.set_health_status(:local_quorum, true)
      HealthStatus.set_health_status(:one, true)
      :ok
    else
      {:error, :health_check_bad} ->
        HealthStatus.set_health_status(:local_quorum, false)

        with {:ok, client} <- Database.connect(),
             :ok <- Queries.check_astarte_health(client, :one) do
          HealthStatus.set_health_status(:one, true)
          {:error, :degraded_health}
        else
          {:error, :health_check_bad} ->
            HealthStatus.set_health_status(:one, false)
            {:error, :bad_health}

          {:error, :database_connection_error} ->
            HealthStatus.set_health_status(:one, false)
            {:error, :bad_health}
        end

      {:error, :database_connection_error} ->
        HealthStatus.set_health_status(:local_quorum, false)
        HealthStatus.set_health_status(:one, false)
        {:error, :bad_health}
    end
  end
end
