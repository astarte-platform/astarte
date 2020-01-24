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

defmodule Astarte.PairingWeb.Metrics.PairingInstrumenter do
  use Prometheus.Metric

  @counter_specs [
    name: :register_requests_total,
    help: "Pairing requests total count",
    labels: [:realm]
  ]

  @get_credentials_specs [
    name: :credential_requests_total,
    help: "Get credentials requests total count",
    labels: [:realm]
  ]

  def setup do
    Counter.declare(@counter_specs)
    Counter.declare(@get_credentials_specs)

    events = [
      [:astarte, :pairing, :register_new_device],
      [:astarte, :pairing, :get_credentials]
    ]

    :telemetry.attach_many("astarte-pairing-prometheus", events, &__MODULE__.handle_event/4, nil)
  end

  def handle_event(
        [:astarte, :pairing, :register_new_device],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(
      name: :register_requests_total,
      labels: [realm]
    )
  end

  def handle_event(
        [:astarte, :pairing, :get_credentials],
        _measurements,
        %{realm: realm} = _metadata,
        _config
      ) do
    Counter.inc(
      name: :credential_requests_total,
      labels: [realm]
    )
  end
end
