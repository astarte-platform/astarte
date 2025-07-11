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

  alias Astarte.Pairing.Health
  alias Astarte.DataAccess.Health.Health, as: DataAccessHealth

  describe "health" do
    test "returns :ready when the database status is ready" do
      Mimic.stub(DataAccessHealth, :get_health, fn -> {:ok, %{status: :ready}} end)

      assert :ready = Health.get_health()
    end

    test "returns :bad when the database status is bad" do
      Mimic.stub(DataAccessHealth, :get_health, fn -> {:ok, %{status: :bad}} end)

      assert :bad = Health.get_health()
    end

    test "returns :ready when the database status is degraded" do
      Mimic.stub(DataAccessHealth, :get_health, fn -> {:ok, %{status: :degraded}} end)

      assert :ready = Health.get_health()
    end

    test "returns :bad when the database returns an error" do
      Mimic.stub(DataAccessHealth, :get_health, fn -> {:ok, %{status: :error}} end)

      assert :bad = Health.get_health()
    end
  end
end
