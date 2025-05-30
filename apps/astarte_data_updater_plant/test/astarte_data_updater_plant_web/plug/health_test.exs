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

defmodule Astarte.DataUpdaterPlantWeb.HealthPlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Mimic

  alias Astarte.DataAccess.Health.Health
  alias Astarte.DataUpdaterPlantWeb.HealthPlug

  setup :verify_on_exit!

  @opts HealthPlug.init([])

  test "returns 200 OK when health is :ready" do
    Mimic.expect(Health, :get_health, fn -> {:ok, %{status: :ready}} end)

    conn =
      conn(:get, "/health")
      |> HealthPlug.call(@opts)

    assert conn.status == 200
    assert conn.resp_body == ""
    assert conn.halted
  end

  test "returns 200 OK when health is :degraded" do
    Mimic.expect(Health, :get_health, fn -> {:ok, %{status: :degraded}} end)

    conn =
      conn(:get, "/health")
      |> HealthPlug.call(@opts)

    assert conn.status == 200
    assert conn.resp_body == ""
    assert conn.halted
  end

  test "returns 503 Service Unavailable when health is :bad" do
    Mimic.expect(Health, :get_health, fn -> {:ok, %{status: :bad}} end)

    conn =
      conn(:get, "/health")
      |> HealthPlug.call(@opts)

    assert conn.status == 503
    assert conn.resp_body == ""
    assert conn.halted
  end

  test "returns 503 Service Unavailable when health is :error" do
    Mimic.expect(Health, :get_health, fn -> {:ok, %{status: :error}} end)

    conn =
      conn(:get, "/health")
      |> HealthPlug.call(@opts)

    assert conn.status == 503
    assert conn.resp_body == ""
    assert conn.halted
  end

  test "returns 500 Internal Server Error when get_health raises" do
    Mimic.expect(Health, :get_health, fn -> raise "fail" end)

    conn =
      conn(:get, "/health")
      |> HealthPlug.call(@opts)

    assert conn.status == 500
    assert conn.resp_body == ""
    assert conn.halted
  end

  test "passes through for non-/health path" do
    conn =
      conn(:get, "/other")
      |> HealthPlug.call(@opts)

    refute conn.halted
    assert conn.status == nil
  end

  test "passes through for non-GET method" do
    conn =
      conn(:post, "/health")
      |> HealthPlug.call(@opts)

    refute conn.halted
    assert conn.status == nil
  end
end
