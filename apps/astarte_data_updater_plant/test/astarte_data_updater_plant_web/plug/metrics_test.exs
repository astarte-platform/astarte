#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlantWeb.MetricsPlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Mimic

  alias Astarte.DataUpdaterPlantWeb.MetricsPlug

  setup :verify_on_exit!

  @opts MetricsPlug.init([])

  test "returns 200 OK and metrics for GET /metrics" do
    Mimic.expect(TelemetryMetricsPrometheus.Core, :scrape, fn -> "metrics_data" end)

    conn =
      conn(:get, "/metrics")
      |> MetricsPlug.call(@opts)

    assert conn.status == 200
    assert conn.resp_body == "metrics_data"
    assert conn.halted
  end

  test "passes through for non-/metrics path" do
    conn =
      conn(:get, "/other")
      |> MetricsPlug.call(@opts)

    refute conn.halted
    assert conn.status == nil
  end

  test "passes through for non-GET method" do
    conn =
      conn(:post, "/metrics")
      |> MetricsPlug.call(@opts)

    refute conn.halted
    assert conn.status == nil
  end
end
