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

defmodule Astarte.AppEngine.APIWeb.Metrics.AppEngineInstrumenter do
  use Prometheus.Metric

  @sent_messages_specs [
    name: :sent_messages_total,
    help: "AppEngine sent messages count",
    labels: [:realm]
  ]

  @exchanged_bytes_specs [
    name: :exchanged_bytes_total,
    help: "AppEngine exchanged bytes count",
    labels: [:realm]
  ]

  @opened_rooms_specs [
    name: :opened_rooms,
    help: "AppEngine opened rooms count",
    labels: [:realm]
  ]

  @sent_events_specs [
    name: :sent_events_total,
    help: "AppEngine sent events count",
    labels: [:realm]
  ]

  @discarded_events_specs [
    name: :discarded_events_total,
    help: "AppEngine discarded events count",
    labels: [:realm]
  ]

  def setup do
    Counter.declare(@sent_messages_specs)
    Counter.declare(@exchanged_bytes_specs)
    Gauge.declare(@opened_rooms_specs)
    Counter.declare(@sent_events_specs)
    Counter.declare(@discarded_events_specs)

    events = [
      [:astarte, :appengine, :device, :message_sent],
      [:astarte, :appengine, :channels, :room_opened],
      [:astarte, :appengine, :channels, :room_closed],
      [:astarte, :appengine, :channels, :event_sent],
      [:astarte, :appengine, :channels, :event_discarded]
    ]

    :telemetry.attach_many(
      "astarte-appengine-prometheus",
      events,
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event(
        [:astarte, :appengine, :device, :message_sent],
        %{exchanged_bytes: exchanged_bytes} = _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(name: :sent_messages_total, labels: [realm])
    Counter.inc([name: :exchanged_bytes_total, labels: [realm]], exchanged_bytes)
  end

  def handle_event(
        [:astarte, :appengine, :channels, :room_opened],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Gauge.inc(name: :opened_rooms, labels: [realm])
  end

  def handle_event(
        [:astarte, :appengine, :channels, :room_closed],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Gauge.dec(name: :opened_rooms, labels: [realm])
  end

  def handle_event(
        [:astarte, :appengine, :channels, :event_sent],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(name: :sent_events_total, labels: [realm])
  end

  def handle_event(
        [:astarte, :appengine, :channels, :event_discarded],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(name: :discarded_events_total, labels: [realm])
  end
end
