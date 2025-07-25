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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.HousekeepingWeb.Telemetry.DatabaseEvents do
  @moduledoc """
    Telemetry handler for database events.

    This module listens to database events and emits telemetry events
    with the relevant measurements and metadata.
  """

  @bounce_events [
    [:prepare_query, :stop],
    [:prepare_query, :exception],
    [:execute, :stop],
    [:execute, :exception],
    [:cluster, :control_connection, :failed_to_connect],
    [:failed_to_connect]
  ]

  require Logger
  alias Astarte.HousekeepingWeb.TelemetryTaskSupervisor

  @doc """
  Handles telemetry events related to database operations.

  See the documentation of Xandra for more details on the events:
  https://hexdocs.pm/xandra/telemetry-events.html

  This handler drops the `:xandra` prefix from the event name and
  executes the telemetry event with the provided measurements and metadata.
  """
  def handle_event([:xandra | event], measurements, metadata, :expose) do
    with :bounce <- validate_event(event) do
      Task.Supervisor.start_child(TelemetryTaskSupervisor, fn ->
        with :ok <- filter_event(event, metadata) do
          :telemetry.execute(
            [:astarte, :housekeeping, :database] ++ event,
            measurements,
            metadata
          )
        end
      end)
    end
  end

  def handle_event(event, measurements, metadata, :log) do
    Xandra.Telemetry.handle_event(event, measurements, metadata, :no_config)
  end

  defp validate_event(event) do
    case event in @bounce_events do
      true -> :bounce
      false -> :ok
    end
  end

  defp filter_event([:execute_query, _], metadata), do: has_reason(metadata)
  defp filter_event([:prepare_query, _], metadata), do: has_reason(metadata)
  defp filter_event(_event, _metadata), do: :ok

  defp has_reason(metadata) do
    case Map.has_key?(metadata, :reason) do
      true -> :ok
      false -> :do_not_bounce
    end
  end
end
