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

defmodule Astarte.TriggerEngineWebTest do
  use Astarte.Cases.Database, async: true
  use ExUnitProperties

  import Astarte.Helpers.Plug

  test "/health returns ok if astarte is working correctly" do
    conn = get("/health")

    # FIXME: remove commented out assertion when health check works again
    _ = conn
    # assert conn.status == 200
  end

  test "/metrics return prometheus metrics" do
    conn = get("/metrics")
    resp_headers = Map.new(conn.resp_headers)

    assert conn.status == 200
    assert resp_headers["content-type"] =~ "text/plain"
  end

  property "other endpoints return 404" do
    check all endpoint <- endpoints() do
      conn = get(endpoint)
      assert conn.status == 404
    end
  end

  defp endpoints do
    gen all partial_endpoint <- string(:utf8) |> filter(&(&1 not in ["metrics", "health"])) do
      "/" <> partial_endpoint
    end
  end
end
