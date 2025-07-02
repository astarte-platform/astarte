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

defmodule Astarte.RealmManagement.APIWeb.Telemetry.APIUsage do
  alias Astarte.RealmManagement.APIWeb.TelemetryTaskSupervisor

  @api_prefix "v1"

  def handle_event([:cowboy, :request, :stop], measurements, metadata, _config) do
    %{req_body_length: req_body_length, resp_body_length: resp_body_length} = measurements
    %{req: %{path: path}} = metadata

    # Offload to a task to isolate execution time and failure
    Task.Supervisor.start_child(TelemetryTaskSupervisor, fn ->
      case String.split(path, "/", trim: true) do
        [@api_prefix, realm | _] ->
          measurements = %{
            request_body_bytes: req_body_length,
            response_body_bytes: resp_body_length
          }

          metadata = %{realm: realm}

          :telemetry.execute(
            [:astarte, :realm_management, :api, :request],
            measurements,
            metadata
          )

        _ ->
          :ok
      end
    end)
  end
end
