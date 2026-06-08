#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Astarte.Pairing.HealthTest do
  use Astarte.Cases.Data, async: true
  use Mimic

  alias Astarte.DataAccess.Health, as: DataAccessHealth
  alias Astarte.Pairing.Health

  describe "health" do
    test "returns :ready when the database status is ready and cfssl is available" do
      stub(DataAccessHealth, :get_health, fn -> :ready end)
      expect(HTTPoison, :get, fn _ -> {:ok, %HTTPoison.Response{status_code: 200}} end)

      assert :ready = Health.get_health()
    end

    test "returns :bad when the database status is bad" do
      stub(DataAccessHealth, :get_health, fn -> :bad end)

      assert :bad = Health.get_health()
    end

    test "returns :ready when the database status is degraded" do
      stub(DataAccessHealth, :get_health, fn -> :degraded end)
      expect(HTTPoison, :get, fn _ -> {:ok, %HTTPoison.Response{status_code: 200}} end)

      assert :ready = Health.get_health()
    end

    test "returns :bad when the database returns an error" do
      stub(DataAccessHealth, :get_health, fn -> :error end)

      assert :bad = Health.get_health()
    end

    test "returns :bad when cfssl returns an error" do
      stub(DataAccessHealth, :get_health, fn -> :degraded end)
      expect(HTTPoison, :get, fn _ -> {:ok, %HTTPoison.Response{status_code: 500}} end)

      assert :bad = Health.get_health()
    end
  end

  describe "rpc_healthcheck/0" do
    test "returns ok when health is ready" do
      Health
      |> expect(:get_health, fn -> :ready end)

      assert Health.rpc_healthcheck() == :ok
    end

    test "raises when health is bad" do
      Health
      |> expect(:get_health, fn -> :bad end)

      assert_raise RuntimeError, fn -> Health.rpc_healthcheck() end
    end
  end
end
