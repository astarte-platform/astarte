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

defmodule Astarte.DataAccess.Device do
  require Logger
  alias Astarte.Core.Device
  alias CQEx.Query
  alias CQEx.Result

  @spec interface_version(:cqerl.client(), Device.device_id(), String.t()) ::
          {:ok, integer} | {:error, atom}
  def interface_version(client, device_id, interface) do
    device_introspection_statement = """
    SELECT introspection
    FROM devices
    WHERE device_id=:device_id
    """

    device_introspection_query =
      Query.new()
      |> Query.statement(device_introspection_statement)
      |> Query.put(:device_id, device_id)

    with {:ok, result} <- Query.call(client, device_introspection_query),
         device_row when is_list(device_row) <- Result.head(result),
         introspection <- Keyword.get(device_row, :introspection) || [],
         {_interface_name, interface_major} <-
           List.keyfind(introspection, interface, 0, :interface_not_found) do
      {:ok, interface_major}
    else
      :empty_dataset ->
        Logger.debug("interface_version: device not found #{inspect(device_id)}")
        {:error, :device_not_found}

      :interface_not_found ->
        # TODO: report device introspection here for debug purposes
        Logger.warn(
          "interface_version: interface #{inspect(interface)} not found in device #{inspect(device_id)} introspection"
        )

        {:error, :interface_not_in_introspection}

      %{acc: _, msg: error_message} ->
        Logger.warn("interface_version: database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        # DB Error
        Logger.warn("interface_version: failed with reason #{inspect(reason)}")
        {:error, :database_error}
    end
  end
end
