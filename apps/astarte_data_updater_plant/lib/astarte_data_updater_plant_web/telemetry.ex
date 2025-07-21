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
        tags: [:realm, :event_type]
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
      ),

      # ControlHandler specific metrics
      last_value("astarte.data_updater_plant.control_handler.properties_prune.duration",
        tags: [:realm, :prune_type],
        unit: {:native, :millisecond},
        description: "Time taken to purge device properties"
      ),
      sum("astarte.data_updater_plant.control_handler.properties_prune.payload_size",
        tags: [:realm, :prune_type],
        description: "Size of properties purge payloads"
      ),
      last_value("astarte.data_updater_plant.control_handler.payload_decompression.duration",
        tags: [:realm, :result],
        unit: {:native, :microsecond},
        description: "Time taken to decompress control payloads"
      ),
      sum("astarte.data_updater_plant.control_handler.payload_decompression.compressed_size",
        tags: [:realm, :result],
        description: "Size of compressed payloads"
      ),
      sum("astarte.data_updater_plant.control_handler.payload_decompression.uncompressed_size",
        tags: [:realm, :result],
        description: "Size of uncompressed payloads"
      ),
      counter("astarte.data_updater_plant.control_handler.unexpected_control.count",
        tags: [:realm, :control_path],
        description: "Unexpected control messages received"
      ),
      sum("astarte.data_updater_plant.control_handler.unexpected_control.payload_size",
        tags: [:realm, :control_path],
        description: "Size of unexpected control message payloads"
      ),
      counter("astarte.data_updater_plant.control_handler.interface_loading.count",
        tags: [:realm, :interface, :result],
        description: "Interface loading attempts during control processing"
      ),
      last_value("astarte.data_updater_plant.control_handler.vmq_publish.duration",
        tags: [:realm, :result, :matches],
        unit: {:native, :microsecond},
        description: "Time taken to publish messages via VMQ"
      ),
      sum("astarte.data_updater_plant.control_handler.vmq_publish.payload_size",
        tags: [:realm, :result, :matches],
        description: "Size of payloads published via VMQ"
      ),
      last_value("astarte.data_updater_plant.control_handler.properties_resend.duration",
        tags: [:realm, :result],
        unit: {:native, :millisecond},
        description: "Time taken to resend device properties"
      ),

      # DataHandler specific metrics
      counter("astarte.data_updater_plant.data_handler.interface_cache.count",
        tags: [:realm, :interface, :result],
        description: "Interface cache hit/miss/failed lookups"
      ),
      counter("astarte.data_updater_plant.data_handler.path_cache.count",
        tags: [:realm, :result],
        description: "Path cache hit/miss lookups"
      ),
      counter("astarte.data_updater_plant.data_handler.value_change_check.count",
        tags: [:realm, :has_previous],
        description: "Value change detection attempts"
      ),

      # AMQPDataConsumer specific metrics
      counter("astarte.data_updater_plant.amqp_consumer.channel_crash.count",
        tags: [:queue_name, :reason],
        description: "AMQP channel crashes by queue and reason"
      ),
      # AMQPEventsProducer specific metrics
      counter("astarte.data_updater_plant.amqp_events_producer.channel_crash.count",
        tags: [:reason],
        description: "AMQP events producer channel crashes by reason"
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
