#
# Copyright (C) 2018 Ispirata Srl
#
# This file is part of Astarte.
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#

defmodule Astarte.DataAccess.Device do
  require Logger
  alias CQEx.Query
  alias CQEx.Result

  @spec interface_version(:cqerl.client(), binary, String.t()) :: {:ok, integer} | {:error, atom}
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
         introspection <- Keyword.get(device_row, :introspection, []),
         {_interface_name, interface_major} <-
           List.keyfind(introspection, interface, 0, :interface_not_found) do
      {:ok, interface_major}
    else
      :empty_dataset ->
        Logger.warn("interface_version: device not found #{inspect(device_id)}")
        {:error, :device_not_found}

      :interface_not_found ->
        # TODO: report device introspection here for debug purposes
        Logger.warn(
          "interface_version: interface #{inspect(interface)} not found in device #{
            inspect(device_id)
          } introspection"
        )

        {:error, :interface_not_in_introspection}

      {:error, reason} ->
        # DB Error
        Logger.warn("interface_version: failed with reason #{inspect(reason)}")
        {:error, :db_error}
    end
  end
end
