#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.AppEngine.APIWeb.Metrics.HealthStatus do
  use Prometheus.Metric

  @gauge_name :appengine_api_database_health

  @gauge_spec [
    name: @gauge_name,
    help: "Database connection state, 1 if able to query, 0 if not.",
    labels: [:consistency_level]
  ]

  def setup do
    Gauge.declare(@gauge_spec)
  end

  def set_health_status(consistency_level, ok?)
      when is_atom(consistency_level) and is_boolean(ok?) do
    if ok? do
      Gauge.set([name: @gauge_name, labels: [consistency_level]], 1)
    else
      Gauge.set([name: @gauge_name, labels: [consistency_level]], 0)
    end
  end
end
