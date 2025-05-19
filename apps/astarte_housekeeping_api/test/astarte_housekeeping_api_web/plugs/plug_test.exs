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

defmodule Astarte.Housekeeping.APIWeb.PlugTest do
  use Astarte.Housekeeping.APIWeb.ConnCase, async: true

  alias Astarte.Housekeeping.Mock.DB
  alias Astarte.Housekeeping.APIWeb.HealthPlug

  describe "GET /health" do
    test "init/1 returns nil" do
      assert HealthPlug.init(:anything) == nil
    end

    test "returns 200 OK when status is :ready", %{conn: conn} do
      DB.set_health_status(:READY)

      conn = get(conn, "/health")

      assert conn.status == 200
      assert conn.halted
    end

    test "returns 200 OK when status is :degraded", %{conn: conn} do
      DB.set_health_status(:DEGRADED)

      conn = get(conn, "/health")

      assert conn.status == 200
      assert conn.halted
    end

    test "returns 503 when status is :bad", %{conn: conn} do
      DB.set_health_status(:BAD)

      conn = get(conn, "/health")

      assert conn.status == 503
      assert conn.halted
    end

    test "returns 503 when status is :error", %{conn: conn} do
      DB.set_health_status(:ERORR)

      conn = get(conn, "/health")

      assert conn.status == 503
      assert conn.halted
    end

    test "/metrics return prometheus metrics", %{conn: conn} do
      conn = get(conn, "/metrics")
      resp_headers = Map.new(conn.resp_headers)

      assert conn.status == 200
      assert resp_headers["content-type"] =~ "text/plain"
    end
  end
end
