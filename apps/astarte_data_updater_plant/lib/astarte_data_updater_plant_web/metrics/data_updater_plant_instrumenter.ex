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

defmodule Astarte.DataUpdaterPlantWeb.Metrics.DataUpdaterPlantInstrumenter do
  use Prometheus.Metric

  @connection_counter_specs [
    name: :device_connections_total,
    help: "DataUpdaterPlant devices connection count",
    labels: [:realm]
  ]

  @disconnection_counter_specs [
    name: :device_disconnections_total,
    help: "DataUpdaterPlant devices disconnection count",
    labels: [:realm]
  ]

  @connected_devices_specs [
    name: :connected_devices,
    help: "DataUpdaterPlant count of devices currently connected",
    labels: [:realm]
  ]

  @discarded_messages_spec [
    name: :discarded_messages_total,
    help: "DataUpdaterPlant discarded messages count",
    labels: [:realm]
  ]

  @clean_session_requests_spec [
    name: :clean_session_requests_total,
    help: "DataUpdaterPlant clean session requests count",
    labels: [:realm]
  ]

  @processed_messages_spec [
    name: :processed_messages_total,
    help: "DataUpdaterPlant processed messages count",
    labels: [:realm, :interface_type]
  ]

  @discarded_control_messages_spec [
    name: :discarded_control_messages_total,
    help: "DataUpdaterPlant discarded control messages count",
    labels: [:realm]
  ]

  @processed_introspection_spec [
    name: :processed_introspections_total,
    help: "DataUpdaterPlant processed introspections count",
    labels: [:realm]
  ]

  @discarded_introspection_spec [
    name: :discarded_introspections_total,
    help: "DataUpdaterPlant discarded introspections count",
    labels: [:realm]
  ]

  @processed_empty_cache_spec [
    name: :processed_empty_cache_total,
    help: "DataUpdaterPlant process empty cache count",
    labels: [:realm]
  ]

  @exchanged_bytes_spec [
    name: :exchanged_bytes_total,
    help: "DataUpdaterPlant exhanged bytes count",
    labels: [:realm]
  ]

  @published_events_spec [
    name: :published_events_total,
    help: "DataUpdaterPlant published events count",
    labels: [:realm, :topic]
  ]

  @detected_crashes_spec [
    name: :detected_crashes_total,
    help: "DataUpdaterPlant crash detected count",
    labels: []
  ]

  def setup do
    Counter.declare(@connection_counter_specs)
    Counter.declare(@disconnection_counter_specs)
    Gauge.declare(@connected_devices_specs)
    Counter.declare(@discarded_messages_spec)
    Counter.declare(@clean_session_requests_spec)
    Counter.declare(@processed_messages_spec)
    Counter.declare(@discarded_control_messages_spec)
    Counter.declare(@processed_introspection_spec)
    Counter.declare(@discarded_introspection_spec)
    Counter.declare(@processed_empty_cache_spec)
    Counter.declare(@exchanged_bytes_spec)
    Counter.declare(@published_events_spec)
    Counter.declare(@detected_crashes_spec)

    events = [
      [:astarte, :data_updater_plant, :data_updater, :device_connection],
      [:astarte, :data_updater_plant, :data_updater, :device_disconnection],
      [:astarte, :data_updater_plant, :data_updater, :discarded_message],
      [:astarte, :data_updater_plant, :data_updater, :clean_session_request],
      [:astarte, :data_updater_plant, :data_updater, :processed_message],
      [:astarte, :data_updater_plant, :data_updater, :discarded_control_message],
      [:astarte, :data_updater_plant, :data_updater, :processed_introspection],
      [:astarte, :data_updater_plant, :data_updater, :discarded_introspection],
      [:astarte, :data_updater_plant, :data_updater, :processed_empty_cache],
      [:astarte, :data_updater_plant, :data_updater, :exchanged_bytes],
      [:astarte, :data_updater_plant, :triggers_handler, :published_event],
      [:astarte, :data_updater_plant, :data_updater, :detected_crash]
    ]

    :telemetry.attach_many(
      "astarte-data-updater-plant-prometheus",
      events,
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event(
        [:astarte, :data_updater_plant, :data_updater, :device_connection],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(
      name: :device_connections_total,
      labels: [realm]
    )

    Gauge.inc(
      name: :connected_devices,
      labels: [realm]
    )
  end

  def handle_event(
        [:astarte, :data_updater_plant, :data_updater, :device_disconnection],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(
      name: :device_disconnections_total,
      labels: [realm]
    )

    Gauge.dec(
      name: :connected_devices,
      labels: [realm]
    )
  end

  def handle_event(
        [:astarte, :data_updater_plant, :data_updater, :discarded_message],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(
      name: :discarded_messages_total,
      labels: [realm]
    )
  end

  def handle_event(
        [:astarte, :data_updater_plant, :data_updater, :clean_session_request],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(
      name: :clean_session_requests_total,
      labels: [realm]
    )

    Gauge.dec(
      name: :connected_devices,
      labels: [realm]
    )
  end

  def handle_event(
        [:astarte, :data_updater_plant, :data_updater, :processed_message],
        _measurements,
        %{realm: realm, interface_type: interface_type} = _metadata,
        _config
      ) do
    Counter.inc(
      name: :processed_messages_total,
      labels: [realm, interface_type]
    )
  end

  def handle_event(
        [:astarte, :data_updater_plant, :data_updater, :discarded_control_message],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(
      name: :discarded_control_messages_total,
      labels: [realm]
    )
  end

  def handle_event(
        [:astarte, :data_updater_plant, :data_updater, :processed_introspection],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(
      name: :processed_introspections_total,
      labels: [realm]
    )
  end

  def handle_event(
        [:astarte, :data_updater_plant, :data_updater, :discarded_introspection],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(
      name: :discarded_introspections_total,
      labels: [realm]
    )
  end

  def handle_event(
        [:astarte, :data_updater_plant, :data_updater, :processed_empty_cache],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(
      name: :processed_empty_cache_total,
      labels: [realm]
    )
  end

  def handle_event(
        [:astarte, :data_updater_plant, :data_updater, :exchanged_bytes],
        %{bytes: bytes} = _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(
      [name: :exchanged_bytes_total, labels: [realm]],
      bytes
    )
  end

  def handle_event(
        [:astarte, :data_updater_plant, :triggers_handler, :published_event],
        _measurements,
        %{realm: realm, event_type: event_type} = _metadata,
        _config
      ) do
    Counter.inc(
      name: :published_events_total,
      labels: [realm, event_type]
    )
  end

  def handle_event(
        [:astarte, :data_updater_plant, :data_updater, :detected_crash],
        _measurements,
        _metadata,
        _config
      ) do
    Counter.inc(name: :detected_crashes_total)
  end
end
