#
# This file is part of Astarte.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Astarte.AppEngine.API.Rooms.Queries do
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult
  require CQEx
  require Logger

  def check_device_exists(client, device_id) do
    device_statement = """
    SELECT device_id
    FROM devices
    WHERE device_id=:device_id
    """

    device_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(device_statement)
      |> DatabaseQuery.put(:device_id, device_id)

    with {:ok, result} <- DatabaseQuery.call(client, device_query),
         device_row when is_list(device_row) <- DatabaseResult.head(result) do
      {:ok, true}
    else
      :empty_dataset ->
        {:ok, false}

      %{acc: _, msg: error_message} ->
        _ = Logger.warning("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warning("Database error, reason: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end
end
