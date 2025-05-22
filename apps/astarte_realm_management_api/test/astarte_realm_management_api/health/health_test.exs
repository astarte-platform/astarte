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

defmodule Astarte.RealmManagement.API.HealthTest do
  use Astarte.RealmManagement.API.DataCase, async: true

  alias Astarte.RealmManagement.API.Health
  alias Astarte.RealmManagement.API.Health.BackendHealth
  alias Astarte.RealmManagement.API.Helpers.RPCMock.DB

  describe "health" do
    test "returns :ready when RealmManagement replies with ready status" do
      DB.set_health_status(:READY)

      assert {:ok, %BackendHealth{status: :ready}} = Health.get_backend_health()
    end

    test "returns :bad when RealmManagement replies with bad status" do
      DB.set_health_status(:BAD)

      assert {:ok, %BackendHealth{status: :bad}} = Health.get_backend_health()
    end

    test "returns :degraded when RealmManagement replies with degraded status" do
      DB.set_health_status(:DEGRADED)

      assert {:ok, %BackendHealth{status: :degraded}} = Health.get_backend_health()
    end

    test "returns :error when get_health returns an unexpected status" do
      DB.set_health_status(:ERROR)

      assert {:ok, %BackendHealth{status: :error}} = Health.get_backend_health()
    end
  end
end
