#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.TriggerEngine.Health do
  @moduledoc """
  Performs health checks of the Pairing service
  """

  alias Astarte.DataAccess.Health.Health, as: DatabaseHealth

  @type health :: :ready | :bad

  @spec get_health() :: health()
  def get_health do
    DatabaseHealth.get_health()
    |> from_database_health()
    |> cast_health_check(&amqp_health/0)
    |> tap(&emit_telemetry/1)
  end

  @spec from_database_health({:ok, %{status: :ready | :degraded | :bad | :error}}) :: health()
  defp from_database_health({:ok, %{status: status}}) do
    case status do
      :ready -> :ready
      :degraded -> :ready
      :bad -> :bad
      :error -> :bad
    end
  end

  defp amqp_health do
    pid = ExRabbitPool.get_connection_worker(:events_consumer_pool)

    case ExRabbitPool.checkout_channel(pid) do
      {:ok, _channel} -> :ready
      {:error, _} -> :bad
    end
  end

  defp telemetry_health(:ready), do: 1
  defp telemetry_health(:bad), do: 0

  defp emit_telemetry(health) do
    :telemetry.execute(
      [:astarte, :trigger_engine, :service],
      %{health: telemetry_health(health)}
    )
  end

  defp cast_health_check(:bad, _), do: :bad
  defp cast_health_check(:ready, next_check), do: next_check.()
end
