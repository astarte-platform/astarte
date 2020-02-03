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

defmodule Astarte.TriggerEngineWeb.Metrics.TriggerEngineInstrumenter do
  use Prometheus.Metric

  @http_actions_executed_specs [
    name: :http_actions_executed_total,
    help: "TriggerEngine total http executed actions",
    labels: [:realm, :status]
  ]

  @consumed_events_specs [
    name: :consumed_events_total,
    help: "TriggerEngine consumed events",
    labels: [:realm]
  ]

  def setup do
    Counter.declare(@http_actions_executed_specs)
    Counter.declare(@consumed_events_specs)

    events = [
      [:astarte, :trigger_engine, :http_action_executed],
      [:astarte, :trigger_engine, :consumed_event]
    ]

    :telemetry.attach_many(
      "astarte-trigger-engine-prometheus",
      events,
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event(
        [:astarte, :trigger_engine, :http_action_executed],
        _measurements,
        %{realm: realm, status: status} = _metadata,
        _config
      ) do
    Counter.inc(
      name: :http_actions_executed_total,
      labels: [realm, status]
    )
  end

  def handle_event(
        [:astarte, :trigger_engine, :consumed_event],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(
      name: :consumed_events_total,
      labels: [realm]
    )
  end
end
