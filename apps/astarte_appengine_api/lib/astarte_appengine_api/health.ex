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

defmodule Astarte.AppEngine.API.Health do
  @moduledoc """
  Health check module for Data Updater Plant service
  """

  alias Astarte.DataAccess.Health.Health, as: DatabaseHealth

  require Logger

  @doc """
  Gets the backend health.
  """
  def get_health do
    with :ready <- database_health(),
         :ready <- vernemq_health() do
      dup_health()
    end
  end

  # Use the existing DataAccess health check for database connectivity
  defp database_health() do
    # When degraded, some database nodes are available so it's still ok
    case DatabaseHealth.get_health() do
      :ready -> :ready
      :degraded -> :ready
      :bad -> :bad
      :error -> :bad
    end
  end

  # Check if VerneMQ service is available via Horde registry lookup
  defp vernemq_health do
    case Horde.Registry.lookup(Registry.VMQPluginRPC, :server) do
      [] ->
        Logger.warning("VerneMQ RPC server not found in registry", tag: "vernemq_health_check")

        :bad

      [{_pid, _value}] ->
        :ready
    end
  end

  # Check if DataUpdaterRPC service is available via Horde registry lookup
  defp dup_health do
    case Horde.Registry.lookup(Registry.DataUpdaterRPC, :server) do
      [] ->
        Logger.warning("DataUpdaterRPC server not found in registry",
          tag: "dataupdaterrpc_health_check"
        )

        :bad

      [{_pid, _value}] ->
        :ready
    end
  end
end
