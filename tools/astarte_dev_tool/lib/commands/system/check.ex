#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule AstarteDevTool.Commands.System.Check do
  @moduledoc false
  require Logger
  alias AstarteDevTool.Utilities.System, as: SystemUtilities

  @astarte_services [
    "astarte-dashboard",
    "astarte-appengine-api",
    "astarte-housekeeping",
    "astarte-housekeeping-api",
    "astarte-grafana",
    "astarte-realm-management",
    "astarte-realm-management-api",
    "astarte-data-updater-plant",
    "astarte-trigger-engine",
    "astarte-pairing",
    "astarte-pairing-api",
    "vernemq",
    "scylla",
    "traefik",
    "rabbitmq",
    "cfssl"
  ]

  def exec(path) do
    case SystemUtilities.system_status(path) do
      {:ok, list} ->
        current_list = list |> Enum.map(fn %{"name" => name} -> name end) |> MapSet.new()

        case Enum.filter(@astarte_services, &(not MapSet.member?(current_list, &1))) do
          [] -> :ok
          rest -> {:error, rest}
        end
    end
  end
end
