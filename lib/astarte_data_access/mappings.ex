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

defmodule Astarte.DataAccess.Mappings do
  alias Astarte.Core.Mapping
  alias CQEx.Query
  require Logger

  @spec fetch_interface_mappings(:cqerl.client(), binary) ::
          {:ok, list(%Mapping{})} | {:error, atom}
  def fetch_interface_mappings(db_client, interface_id) do
    mappings_statement = """
    SELECT endpoint, value_type, reliability, retention, expiry, allow_unset, explicit_timestamp,
      endpoint_id, interface_id
    FROM endpoints
    WHERE interface_id=:interface_id
    """

    mappings_query =
      Query.new()
      |> Query.statement(mappings_statement)
      |> Query.put(:interface_id, interface_id)
      |> Query.consistency(:quorum)

    with {:ok, result} <- Query.call(db_client, mappings_query) do
      mappings = Enum.map(result, &Mapping.from_db_result!/1)

      {:ok, mappings}
    else
      %{acc: _, msg: error_message} ->
        Logger.warn("fetch_interface_mappings: database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("fetch_interface_mappings: failed with reason #{inspect(reason)}")
        {:error, :database_error}
    end
  end

  @spec fetch_interface_mappings_map(:cqerl.client(), binary) :: {:ok, map()} | {:error, atom}
  def fetch_interface_mappings_map(db_client, interface_id) do
    with {:ok, mappings_list} <- fetch_interface_mappings(db_client, interface_id) do
      mappings_map =
        Enum.into(mappings_list, %{}, fn %Mapping{} = mapping ->
          {mapping.endpoint_id, mapping}
        end)

      {:ok, mappings_map}
    end
  end
end
