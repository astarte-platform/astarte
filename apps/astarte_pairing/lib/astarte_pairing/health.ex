#
# This file is part of Astarte.
#
# Copyright 2020-2025 SECO Mind Srl
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

defmodule Astarte.Pairing.Health do
  @moduledoc """
  Performs health checks of the Pairing service
  """

  alias Astarte.DataAccess.Health.Health, as: DatabaseHealth

  @type health :: :ready | :bad

  @doc """
  Gets the backend health.
  """
  @spec get_health() :: health()
  def get_health do
    database_status = DatabaseHealth.get_health() |> from_database_health()

    :telemetry.execute(
      [:astarte, :pairing, :service],
      %{health: telemetry_health(database_status)}
    )

    database_status
  end

  @spec from_database_health({:ok, %{status: :ready | :degraded | :bad | :error}}) :: health()
  defp from_database_health(database_health) do
    # TODO: remove after data access update
    {:ok, %{status: database_health}} = database_health

    # When degraded, some Scylla nodes are available so it's still ok
    case database_health do
      :ready -> :ready
      :degraded -> :ready
      :bad -> :bad
      :error -> :bad
    end
  end

  defp telemetry_health(:ready), do: 1
  defp telemetry_health(:bad), do: 0
end
