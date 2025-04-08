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

defmodule Astarte.Pairing.API.HealthTest do
  use Astarte.Pairing.API.DataCase, async: true

  alias Astarte.Pairing.API.Health
  alias Astarte.DataAccess.Health.Health, as: DataAccessHealth
  alias Astarte.Pairing.API.Health.BackendHealth

  describe "health" do
    test "returns :ready when get_health replies with ready status" do
      Mimic.stub(DataAccessHealth, :get_health, fn -> {:ok, %{status: :ready}} end)

      assert {:ok, %BackendHealth{status: :ready}} = Health.get_backend_health()
    end

    test "returns :bad when get_health replies with bad status" do
      Mimic.stub(DataAccessHealth, :get_health, fn -> {:ok, %{status: :bad}} end)

      assert {:ok, %BackendHealth{status: :bad}} = Health.get_backend_health()
    end

    test "returns :degraded when get_health replies with degraded status" do
      Mimic.stub(DataAccessHealth, :get_health, fn -> {:ok, %{status: :degraded}} end)

      assert {:ok, %BackendHealth{status: :degraded}} = Health.get_backend_health()
    end

    test "returns :error when get_health returns an unexpected status" do
      Mimic.stub(DataAccessHealth, :get_health, fn -> {:ok, %{status: :error}} end)

      assert {:ok, %BackendHealth{status: :error}} = Health.get_backend_health()
    end
  end
end
