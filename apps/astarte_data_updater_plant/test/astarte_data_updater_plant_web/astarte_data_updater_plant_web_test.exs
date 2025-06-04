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

defmodule Astarte.DataUpdaterPlantWeb.AstarteDataUpdaterPlantWebTest do
  use ExUnit.Case, async: true
  use Plug.Test
  use Mimic

  alias Astarte.DataUpdaterPlantWeb.Router
  alias Astarte.DataAccess.Health.Health

  @opts Router.init([])

  describe "Router" do
    test "returns 404 for unknown route" do
      conn = conn(:get, "/unknown") |> Router.call(@opts)
      assert conn.status == 404
      assert conn.resp_body == "Not found"
    end
  end

  describe "/metrics" do
    test "returns 200 OK for GET request" do
      conn = conn(:get, "/metrics") |> Router.call(@opts)

      assert conn.status == 200
      assert conn.halted
    end

    test "passes through for non-GET method" do
      conn = conn(:post, "/metrics") |> Router.call(@opts)

      refute conn.halted
      assert conn.status == 404
    end
  end

  describe "/health" do
    test "returns 200 OK when health is :ready" do
      Mimic.expect(Health, :get_health, fn -> {:ok, %{status: :ready}} end)

      conn = conn(:get, "/health") |> Router.call(@opts)

      assert conn.status == 200
      assert conn.resp_body == ""
      assert conn.halted
    end

    test "returns 200 OK when health is :degraded" do
      Mimic.expect(Health, :get_health, fn -> {:ok, %{status: :degraded}} end)

      conn = conn(:get, "/health") |> Router.call(@opts)

      assert conn.status == 200
      assert conn.resp_body == ""
      assert conn.halted
    end

    test "returns 503 Service Unavailable when health is :bad" do
      Mimic.expect(Health, :get_health, fn -> {:ok, %{status: :bad}} end)

      conn = conn(:get, "/health") |> Router.call(@opts)
      assert conn.status == 503
      assert conn.resp_body == ""
      assert conn.halted
    end

    test "returns 503 Service Unavailable when health is :error" do
      Mimic.expect(Health, :get_health, fn -> {:ok, %{status: :error}} end)

      conn = conn(:get, "/health") |> Router.call(@opts)

      assert conn.status == 503
      assert conn.resp_body == ""
      assert conn.halted
    end

    test "passes through for non-GET method" do
      conn = conn(:post, "/health") |> Router.call(@opts)

      refute conn.halted
      assert conn.status == 404
    end
  end
end
