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

defmodule Astarte.DataAccess.Health.HealthTest do
  use ExUnit.Case, async: false
  alias Astarte.DataAccess.DatabaseTestHelper
  alias Astarte.DataAccess.Health.Health

  @create_astarte_kv_store """
  CREATE TABLE IF NOT EXISTS astarte.kv_store (
    group varchar,
    key varchar,
    value blob,
    PRIMARY KEY ((group), key)
  )
  """

  describe "get_health/0" do
    test "returns :ready when the astarte keyspace and required tables are available" do
      on_exit(fn ->
        Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
          DatabaseTestHelper.destroy_astarte_keyspace(conn)
        end)
      end)

      Xandra.Cluster.run(:astarte_data_access_xandra, fn conn ->
        DatabaseTestHelper.create_astarte_keyspace(conn)
        Xandra.execute!(conn, @create_astarte_kv_store)
      end)

      assert Health.get_health() == :ready
    end

    test "returns :bad when health check queries fail" do
      assert Health.get_health() == :bad
    end
  end
end
