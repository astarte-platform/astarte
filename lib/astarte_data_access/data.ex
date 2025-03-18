#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.DataAccess.Data do
  require Logger
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.XandraUtils
  import Ecto.Query
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Realms.IndividualProperty
  alias Astarte.DataAccess.Repo
  alias Ecto.UUID

  require Logger

  @spec fetch_property(
          String.t(),
          Device.device_id(),
          %InterfaceDescriptor{},
          %Mapping{},
          String.t()
        ) :: {:ok, any} | {:error, atom}
  def fetch_property(
        realm,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_properties_dbtable} =
          interface_descriptor,
        mapping,
        path
      )
      when is_binary(device_id) and is_binary(path) do
    keyspace = Realm.keyspace_name(realm)

    value_column =
      mapping.value_type
      |> CQLUtils.type_to_db_column_name()
      |> String.to_atom()

    device_id = UUID.cast!(device_id)
    interface_id = UUID.cast!(interface_descriptor.interface_id)
    endpoint_id = UUID.cast!(mapping.endpoint_id)

    fetch_clause = fetch_clause(device_id, interface_id, endpoint_id, path)

    query =
      from s in interface_descriptor.storage,
        prefix: ^keyspace,
        select: field(s, ^value_column)

    consistency = Consistency.device_info(:read)

    property =
      Repo.fetch_by(query, fetch_clause, consistency: consistency, error: :property_not_set)

    case property do
      nil -> {:error, :property_not_set}
      {:error, err} -> {:error, err}
      {:ok, value} -> {:ok, value}
    end
  end

  @spec path_exists?(
          String.t(),
          Device.device_id(),
          InterfaceDescriptor.t(),
          Mapping.t(),
          String.t()
        ) :: {:ok, boolean} | {:error, atom}
  def path_exists?(
        realm,
        device_id,
        interface_descriptor,
        mapping,
        path
      )
      when is_binary(device_id) and is_binary(path) do
    keyspace = Realm.keyspace_name(realm)
    fetch_clause = fetch_clause(device_id, interface_descriptor, mapping, path)

    consistency = Consistency.domain_model(:read)

    from(IndividualProperty, prefix: ^keyspace, where: ^fetch_clause)
    |> Repo.aggregate(:count, consistency: consistency)
    |> case do
      0 -> {:ok, false}
      1 -> {:ok, true}
    end
  end

  @spec fetch_last_path_update(
          String.t(),
          Device.device_id(),
          InterfaceDescriptor.t(),
          Mapping.t(),
          String.t()
        ) ::
          {:ok, %{value_timestamp: DateTime.t(), reception_timestamp: DateTime.t()}}
          | {:error, atom}
  def fetch_last_path_update(
        realm,
        device_id,
        interface_descriptor,
        mapping,
        path
      )
      when is_binary(device_id) and is_binary(path) do
    keyspace = Realm.keyspace_name(realm)
    fetch_clause = fetch_clause(device_id, interface_descriptor, mapping, path)

    query =
      from IndividualProperty,
        prefix: ^keyspace,
        select: [:datetime_value, :reception_timestamp, :reception_timestamp_submillis]

    with {:ok, property} <- Repo.fetch_by(query, fetch_clause, error: :path_not_set) do
      value_timestamp = property.datetime_value |> DateTime.truncate(:millisecond)
      reception_timestamp = IndividualProperty.reception(property)

      {:ok, %{value_timestamp: value_timestamp, reception_timestamp: reception_timestamp}}
    end
  end

  defp fetch_clause(
         device_id,
         %{interface_id: interface_id} = _interface_descriptor,
         %{endpoint_id: endpoint_id} = _mapping,
         path
       ) do
    fetch_clause(device_id, interface_id, endpoint_id, path)
  end

  defp fetch_clause(device_id, interface_id, endpoint_id, path) do
    [device_id: device_id, interface_id: interface_id, endpoint_id: endpoint_id, path: path]
  end
end
