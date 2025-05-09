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

defmodule Astarte.Housekeeping.API.HealthTest do
  use Astarte.Housekeeping.API.DataCase, async: true

  alias Astarte.Housekeeping.API.Health

  describe "health" do
    test "returns :ready when Housekeeping replies with ready status" do
      assert {:ok, %{status: :ready}} = Health.get_backend_health()
    end

    test "returns :bad when Housekeeping replies with bad status" do
      Astarte.Housekeeping.Mock.DB.set_health_status(:BAD)

      assert {:ok, %{status: :bad}} = Health.get_backend_health()
    end

    test "returns :degraded when Housekeeping replies with degraded status" do
      Astarte.Housekeeping.Mock.DB.set_health_status(:DEGRADED)
      assert {:ok, %{status: :degraded}} = Health.get_backend_health()
    end

    test "returns :error when get_health returns an unexpected status" do
      Astarte.Housekeeping.Mock.DB.set_health_status(:ERROR)
      assert {:ok, %{status: :error}} = Health.get_backend_health()
    end
  end
end
