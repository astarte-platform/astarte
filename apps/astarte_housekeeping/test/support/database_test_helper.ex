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
    query = "DROP KEYSPACE astarte"

    _ = Xandra.Cluster.execute(:xandra, query, %{}, timeout: 60_000)

    :ok
  end

  def realm_cleanup(realm) do
    Xandra.Cluster.run(:xandra, [timeout: 60_000], fn conn ->
      delete_from_astarte_query = """
      DELETE FROM astarte.realms
      WHERE realm_name=:realm_name
      """

      delete_from_astarte_prepared = Xandra.prepare!(conn, delete_from_astarte_query)

      _ = Xandra.execute!(conn, delete_from_astarte_prepared, %{"realm_name" => realm})

      delete_keyspace_query = """
      DROP KEYSPACE #{realm}
      """

      _ = Xandra.execute!(conn, delete_keyspace_query)

      :ok
    end)
  end
end
