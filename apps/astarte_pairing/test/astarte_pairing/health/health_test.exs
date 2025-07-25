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

defmodule Astarte.Pairing.HealthTest do
  use Astarte.Pairing.DataCase, async: true

  alias Astarte.DataAccess.Health.Health, as: DataAccessHealth
  alias Astarte.Pairing.Health

  describe "health" do
    test "returns :ready when the database status is ready and cfssl is available" do
      Mimic.stub(DataAccessHealth, :get_health, fn -> :ready end)
      Mimic.expect(HTTPoison, :get, fn _ -> {:ok, %HTTPoison.Response{status_code: 200}} end)

      assert :ready = Health.get_health()
    end

    test "returns :bad when the database status is bad" do
      Mimic.stub(DataAccessHealth, :get_health, fn -> :bad end)

      assert :bad = Health.get_health()
    end

    test "returns :ready when the database status is degraded" do
      Mimic.stub(DataAccessHealth, :get_health, fn -> :degraded end)
      Mimic.expect(HTTPoison, :get, fn _ -> {:ok, %HTTPoison.Response{status_code: 200}} end)

      assert :ready = Health.get_health()
    end

    test "returns :bad when the database returns an error" do
      Mimic.stub(DataAccessHealth, :get_health, fn -> :error end)

      assert :bad = Health.get_health()
    end

    test "returns :bad when cfssl returns an error" do
      Mimic.stub(DataAccessHealth, :get_health, fn -> :degraded end)
      Mimic.expect(HTTPoison, :get, fn _ -> {:ok, %HTTPoison.Response{status_code: 500}} end)

      assert :bad = Health.get_health()
    end
  end
end
