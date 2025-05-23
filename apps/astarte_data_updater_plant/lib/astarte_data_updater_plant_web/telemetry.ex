#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule Astarte.DataUpdaterPlantWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics
  alias Astarte.DataUpdaterPlant.Config

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      {TelemetryMetricsPrometheus.Core, metrics: metrics()},
      {Plug.Cowboy,
       scheme: :http, plug: Astarte.DataUpdaterPlantWeb.Router, options: [port: Config.port!()]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # VM Metrics
      last_value("vm.memory.total"),
      last_value("vm.memory.processes_used"),
      last_value("vm.memory.processes"),
      last_value("vm.memory.system"),
      last_value("vm.memory.atom"),
      last_value("vm.memory.atom_used"),
      last_value("vm.memory.ets"),
      last_value("vm.memory.code"),
      last_value("vm.system_counts.process_count"),
      last_value("vm.system_counts.atom_count"),
      last_value("vm.system_counts.port_count"),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io"),
      last_value("vm.refresh"),

      # Custom metrics
      counter("astarte.data_updater_plant.data_updater.device_connection.count",
        tags: [:realm]
      ),
      counter("astarte.data_updater_plant.data_updater.device_disconnection.count",
        tags: [:realm]
      ),
      counter("astarte.data_updater_plant.data_updater.discarded_message.count",
        tags: [:realm]
      ),
      counter("astarte.data_updater_plant.data_updater.clean_session_request.count",
        tags: [:realm]
      ),
      counter("astarte.data_updater_plant.data_updater.processed_message.count",
        tags: [:realm, :interface_type]
      ),
      counter("astarte.data_updater_plant.data_updater.discarded_control_message.count",
        tags: [:realm]
      ),
      counter("astarte.data_updater_plant.data_updater.processed_introspection.count",
        tags: [:realm]
      ),
      counter("astarte.data_updater_plant.data_updater.discarded_introspection.count",
        tags: [:realm]
      ),
      counter("astarte.data_updater_plant.data_updater.processed_empty_cache.count",
        tags: [:realm]
      ),
      sum("astarte.data_updater_plant.data_updater.exchanged_bytes.bytes",
        tags: [:realm]
      ),
      counter("astarte.data_updater_plant.triggers_handler.published_event.count",
        tags: [:realm]
      ),
      counter("astarte.data_updater_plant.data_updater.detected_crash.count"),
      last_value("astarte.data_updater_plant.data_updater.handle_data.duration",
        tags: [:realm],
        unit: {:native, :millisecond}
      ),
      last_value("astarte.data_updater_plant.service.health",
        tags: [:status],
        description: "Service state: 1 if good, 0 if not."
      ),
      sum("astarte.data_updater_plant.service.connected_devices.duration",
        tags: [:realm]
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {MyApp, :count_users, []}
    ]
  end
end
