#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.Housekeeping.DatabaseTestHelper do
  alias Astarte.Housekeeping.Queries
  alias Astarte.Housekeeping.Config
  alias Astarte.Core.CQLUtils

  def wait_and_initialize(retries \\ 10) do
    case Queries.initialize_database() do
      :ok ->
        :ok

      {:error, :database_connection_error} ->
        if retries > 0 do
          :timer.sleep(100)
          wait_and_initialize(retries - 1)
        else
          {:error, :database_connection_error}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def drop_astarte_keyspace do
    query =
      "DROP KEYSPACE #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}"

    _ = Xandra.Cluster.execute(:xandra, query, %{}, timeout: 60_000)

    :ok
  end

  def realm_cleanup(realm) do
    Queries.delete_realm(realm)
  end
end
