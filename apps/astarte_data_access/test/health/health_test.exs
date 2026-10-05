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

defmodule Astarte.DataAccess.HealthTest do
  use ExUnit.Case, async: true

  alias Astarte.DataAccess.Health

  import Astarte.DataAccess.Helpers.Database
  import Astarte.DataAccess.Cases.Database

  setup do
    astarte_instance_id = "test#{System.unique_integer([:positive])}"
    setup_database_access(astarte_instance_id)
    %{astarte_instance_id: astarte_instance_id}
  end

  describe "get_health/0" do
    test "returns :ready when the astarte keyspace and required tables are available", context do
      %{astarte_instance_id: astarte_instance_id} = context
      setup_instance(astarte_instance_id, [])

      assert Health.get_health() == :ready
    end

    test "returns :bad when health check queries fail" do
      assert Health.get_health() == :bad
    end
  end
end
