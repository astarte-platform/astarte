#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.Housekeeping.HealthTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.Housekeeping.Health

  describe "rpc_healthcheck/0" do
    test "returns ok when health is ready" do
      Health
      |> expect(:get_health, fn -> :ready end)

      assert Health.rpc_healthcheck() == :ok
    end

    test "returns ok when health is degraded" do
      Health
      |> expect(:get_health, fn -> :degraded end)

      assert Health.rpc_healthcheck() == :ok
    end

    test "raises when health is bad" do
      Health
      |> expect(:get_health, fn -> :bad end)

      assert_raise RuntimeError, fn -> Health.rpc_healthcheck() end
    end

    test "raises when health is error" do
      Health
      |> expect(:get_health, fn -> :error end)

      assert_raise RuntimeError, fn -> Health.rpc_healthcheck() end
    end
  end
end
