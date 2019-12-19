#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.AppEngine.API.Stats.Queries do
  alias Astarte.Core.Realm
  alias Astarte.AppEngine.API.Stats.DevicesStats

  require Logger

  def get_devices_stats(realm) do
    Xandra.Cluster.run(:xandra, fn conn ->
      with {:ok, total_devices_count} <- get_total_devices_count(conn, realm),
           {:ok, connected_devices_count} <- get_connected_devices_count(conn, realm) do
        stats = %DevicesStats{
          total_devices: total_devices_count,
          connected_devices: connected_devices_count
        }

        {:ok, stats}
      else
        {:error, reason} ->
          _ = Logger.warn("Database error: #{inspect(reason)}.", tag: "db_error")
          {:error, :database_error}
      end
    end)
  end

  defp get_total_devices_count(conn, realm) do
    query = """
    SELECT count(device_id)
    FROM :realm.devices
    """

    with {:ok, prepared} <- prepare_with_realm(conn, realm, query),
         {:ok, %Xandra.Page{} = page} <- Xandra.execute(conn, prepared) do
      [%{"system.count(device_id)" => count}] = Enum.to_list(page)

      {:ok, count}
    end
  end

  defp get_connected_devices_count(conn, realm) do
    # TODO: we should do this via DataUpdaterPlant instead of using ALLOW FILTERING
    query = """
    SELECT count(device_id)
    FROM :realm.devices
    WHERE connected=true
    ALLOW FILTERING
    """

    with {:ok, prepared} <- prepare_with_realm(conn, realm, query),
         {:ok, %Xandra.Page{} = page} <- Xandra.execute(conn, prepared, %{}) do
      [%{"system.count(device_id)" => count}] = Enum.to_list(page)

      {:ok, count}
    end
  end

  # TODO: copypasted from Groups.Queries, this is going to be moved to Astarte.DataAccess
  # when we move everything to Xandra
  defp prepare_with_realm(conn, realm_name, query) do
    with {:valid, true} <- {:valid, Realm.valid_name?(realm_name)},
         query_with_realm = String.replace(query, ":realm", realm_name),
         {:ok, prepared} <- Xandra.prepare(conn, query_with_realm) do
      {:ok, prepared}
    else
      {:valid, false} ->
        {:error, :not_found}

      {:error, reason} ->
        _ = Logger.warn("Database error: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end
end
