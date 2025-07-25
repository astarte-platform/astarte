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

defmodule Astarte.TriggerEngineWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics
  alias Astarte.TriggerEngine.Config
  alias Astarte.TriggerEngineWeb.Telemetry.DatabaseEvents

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    attach_handlers()

    children = [
      {Task.Supervisor, name: Astarte.TriggerEngineWeb.TelemetryTaskSupervisor},
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      {TelemetryMetricsPrometheus.Core, metrics: metrics()},
      {Plug.Cowboy,
       scheme: :http, plug: Astarte.TriggerEngineWeb.Router, options: [port: Config.port!()]}
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
      counter("astarte.trigger_engine.http_action_executed.count",
        tags: [:realm, :status],
        description: "TriggerEngine total http executed actions."
      ),
      sum("astarte.trigger_engine.http_action_executed.payload_bytes",
        tags: [:realm, :status],
        description: "TriggerEngine total http executed actions payload size, in bytes."
      ),
      counter("astarte.trigger_engine.consumed_event.count",
        tags: [:realm],
        description: "TriggerEngine consumed events."
      ),
      last_value("astarte.trigger_engine.service.health",
        description: "Service state: 1 if good, 0 if not."
      ),
      last_value("astarte.trigger_engine.handle_event.start",
        tags: [:realm],
        unit: {:native, :millisecond}
      ),
      last_value("astarte.trigger_engine.handle_event.duration",
        tags: [:realm],
        unit: {:native, :millisecond}
      ),

      # Database exception metrics
      counter("astarte.trigger_engine.database.execute_query.exception.count",
        tags: [:query, :reason, :kind, :stacktrace],
        tag_values: &to_valid_values/1,
        unit: {:native, :second}
      ),
      counter("astarte.trigger_engine.database.execute_query.stop.count",
        tags: [:query, :reason],
        tag_values: &to_valid_values/1,
        unit: {:native, :second}
      ),

      # Database preparation metrics
      counter("astarte.trigger_engine.database.prepare_query.exception.count",
        tags: [:query, :reason, :kind, :stacktrace],
        tag_values: &to_valid_values/1,
        unit: {:native, :second}
      ),
      counter("astarte.trigger_engine.database.prepare_query.stop.count",
        tags: [:query, :reason],
        tag_values: &to_valid_values/1,
        unit: {:native, :second}
      ),

      # Database connection metrics
      counter(
        "astarte.trigger_engine.database.cluster.control_connection.failed_to_connect.count",
        tag_values: &to_valid_values/1,
        tags: [:cluster_name, :host, :reason]
      ),
      counter("astarte.trigger_engine.database.failed_to_connect.conut",
        tag_values: &to_valid_values/1,
        tags: [:connection_name, :address, :port]
      )
    ]
  end

  defp to_valid_values(%{query: query, reason: reason}) do
    %{query: query.statement, reason: Xandra.Error.message(reason)}
  end

  defp to_valid_values(%{cluster_name: cluster_name, host: host, reason: reason}) do
    %{cluster_name: cluster_name, host: inspect(host), reason: to_string(reason)}
  end

  defp to_valid_values(%{connection_name: connection_name, address: address, port: port}) do
    %{connection_name: connection_name, address: inspect(address), port: inspect(port)}
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {MyApp, :count_users, []}
    ]
  end

  defp attach_handlers do
    :telemetry.attach_many(
      DatabaseEvents,
      xandra_events(),
      &DatabaseEvents.handle_event/4,
      Config.database_events_handling_method!()
    )
  end

  defp xandra_events do
    [
      [:xandra, :connected],
      [:xandra, :disconnected],
      [:xandra, :failed_to_connect],
      [:xandra, :prepared_cache, :hit],
      [:xandra, :prepared_cache, :miss],
      [:xandra, :prepare_query, :stop],
      [:xandra, :execute_query, :stop],
      [:xandra, :client_timeout],
      [:xandra, :timed_out_response],
      [:xandra, :server_warnings],
      [:xandra, :cluster, :change_event],
      [:xandra, :cluster, :control_connection, :connected],
      [:xandra, :cluster, :control_connection, :disconnected],
      [:xandra, :cluster, :control_connection, :failed_to_connect],
      [:xandra, :cluster, :pool, :started],
      [:xandra, :cluster, :pool, :restarted],
      [:xandra, :cluster, :pool, :stopped],
      [:xandra, :cluster, :discovered_peers]
    ]
  end
end
