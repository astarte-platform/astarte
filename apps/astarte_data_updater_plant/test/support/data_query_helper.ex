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

defmodule Astarte.DataUpdaterPlant.DataQueryHelper do
  @moduledoc """
  This module provides helper functions to query for values stored in db data tables
  for the three interface types [properties, individual datastream, object datastream]
  during DUP tests. Only retrieval of last data point is supported.
  TODO consider to integrate this into DataAccess module.
  """

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Interface
  alias Astarte.DataAccess.Realms.IndividualDatastream
  alias Astarte.DataAccess.Realms.IndividualProperty
  alias Astarte.DataAccess.Repo

  import Ecto.Query

  @spec query_endpoint_data(
          Interface.t(),
          String.t(),
          binary(),
          String.t(),
          :individual_datastream | :property
        ) :: list(map())
  def query_endpoint_data(interface, endpoint_path, device_id, keyspace, :property) do
    interface_id = CQLUtils.interface_id(interface.name, interface.major_version)
    endpoint_id = CQLUtils.endpoint_id(interface.name, interface.major_version, endpoint_path)

    do_query_property(device_id, interface_id, endpoint_id, endpoint_path, keyspace)
  end

  def query_endpoint_data(interface, endpoint_path, device_id, keyspace, :individual_datastream) do
    interface_id = CQLUtils.interface_id(interface.name, interface.major_version)
    endpoint_id = CQLUtils.endpoint_id(interface.name, interface.major_version, endpoint_path)

    do_query_individual_datastream(device_id, interface_id, endpoint_id, endpoint_path, keyspace)
  end

  @spec query_endpoint_data(
          Interface.t(),
          String.t(),
          list(atom()),
          binary(),
          String.t(),
          boolean(),
          :object_datastream
        ) :: list(map())
  def query_endpoint_data(
        interface,
        common_endpoint_path,
        endpoints,
        device_id,
        keyspace,
        encrypted,
        :object_datastream
      ) do
    interface_storage_id =
      CQLUtils.interface_name_to_table_name(interface.name, interface.major_version)

    columns_to_select = endpoints |> maybe_add_dek_column(encrypted)

    do_query_object_datastream(
      interface_storage_id,
      device_id,
      common_endpoint_path,
      columns_to_select,
      keyspace
    )
  end

  defp do_query_property(device_id, interface_id, endpoint_id, path, keyspace) do
    value_query_params =
      from(i in IndividualProperty,
        where:
          i.device_id == ^device_id and
            i.interface_id == ^interface_id and
            i.endpoint_id == ^endpoint_id and
            i.path == ^path
      )

    Repo.all(value_query_params, prefix: keyspace)
  end

  defp do_query_individual_datastream(device_id, interface_id, endpoint_id, path, keyspace) do
    value_query_params =
      from(i in IndividualDatastream,
        where:
          i.device_id == ^device_id and
            i.interface_id == ^interface_id and
            i.endpoint_id == ^endpoint_id and
            i.path == ^path
      )

    Repo.all(value_query_params, prefix: keyspace)
  end

  defp do_query_object_datastream(interface_storage_id, device_id, path, columns, keyspace) do
    value_query_params =
      from(i in interface_storage_id,
        where:
          i.device_id == ^device_id and
            i.path == ^path,
        select: ^columns
      )

    Repo.all(value_query_params, prefix: keyspace)
  end

  defp maybe_add_dek_column(columns, encrypted) do
    case encrypted do
      true ->
        columns ++ [:encrypted_dek]

      _ ->
        columns
    end
  end
end
