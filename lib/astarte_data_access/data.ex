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

defmodule Astarte.DataAccess.Data do
  require Logger
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias CQEx.Query
  alias CQEx.Result

  @spec fetch_property(:cqerl.client(), binary, %InterfaceDescriptor{}, %Mapping{}, String.t()) ::
          {:ok, any} | {:error, atom}
  def fetch_property(
        db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_properties_dbtable} =
          interface_descriptor,
        %Mapping{} = mapping,
        path
      )
      when is_binary(device_id) and is_binary(path) do
    value_column = CQLUtils.type_to_db_column_name(mapping.value_type)

    fetch_property_value_statement = """
    SELECT #{value_column}
    FROM "#{interface_descriptor.storage}"
    WHERE device_id=:device_id AND interface_id=:interface_id
      AND endpoint_id=:endpoint_id AND path=:path
    """

    fetch_property_query =
      Query.new()
      |> Query.statement(fetch_property_value_statement)
      |> Query.put(:device_id, device_id)
      |> Query.put(:interface_id, interface_descriptor.interface_id)
      |> Query.put(:endpoint_id, mapping.endpoint_id)
      |> Query.put(:path, path)
      |> Query.consistency(:quorum)

    with {:ok, result} <- Query.call(db_client, fetch_property_query),
         [{_column, value}] when not is_nil(value) <- Result.head(result) do
      {:ok, value}
    else
      :empty_dataset ->
        {:error, :property_not_set}

      [{column, nil}] when is_atom(column) ->
        Logger.warn("Unexpected null value on #{path}, mapping: #{inspect(mapping)}.")
        {:error, :undefined_property}

      any_error ->
        Logger.warn("Database error while retrieving property: #{inspect(any_error)}")
        {:error, :database_error}
    end
  end
end
