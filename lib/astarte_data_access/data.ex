#
# This file is part of Astarte.
#
# Copyright 2018 - 2024 SECO Mind Srl
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
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping

  @individual_properties_table "individual_properties"

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
    XandraUtils.run(
      realm,
      &do_fetch_property(&1, &2, device_id, interface_descriptor, mapping, path)
    )
  end

  defp do_fetch_property(conn, keyspace_name, device_id, interface_descriptor, mapping, path) do
    value_column = CQLUtils.type_to_db_column_name(mapping.value_type)

    statement = """
    SELECT #{value_column}
    FROM #{keyspace_name}."#{interface_descriptor.storage}"
    WHERE device_id=:device_id AND interface_id=:interface_id
      AND endpoint_id=:endpoint_id AND path=:path
    """

    params = %{
      device_id: device_id,
      interface_id: interface_descriptor.interface_id,
      endpoint_id: mapping.endpoint_id,
      path: path
    }

    consistency = Consistency.device_info(:read)

    with {:ok, %Xandra.Page{} = page} <-
           XandraUtils.retrieve_page(conn, statement, params, consistency: consistency) do
      retrieve_property_value(page, value_column)
    end
  end

  defp retrieve_property_value(%Xandra.Page{} = page, value_column) do
    value_atom = String.to_existing_atom(value_column)

    case Enum.to_list(page) do
      [] ->
        {:error, :property_not_set}

      [%{^value_atom => value}] ->
        if value != nil do
          {:ok, value}
        else
          {:error, :undefined_property}
        end
    end
  end

  @spec path_exists?(
          String.t(),
          Device.device_id(),
          %InterfaceDescriptor{},
          %Mapping{},
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
    XandraUtils.run(
      realm,
      &do_path_exists?(&1, &2, device_id, interface_descriptor, mapping, path)
    )
  end

  defp do_path_exists?(conn, keyspace_name, device_id, interface_descriptor, mapping, path) do
    # TODO: do not hardcode individual_properties here
    statement = """
    SELECT COUNT(*)
    FROM #{keyspace_name}.#{@individual_properties_table}
    WHERE device_id=:device_id AND interface_id=:interface_id
      AND endpoint_id=:endpoint_id AND path=:path
    """

    params = %{
      device_id: device_id,
      interface_id: interface_descriptor.interface_id,
      endpoint_id: mapping.endpoint_id,
      path: path
    }

    consistency = Consistency.domain_model(:read)

    with {:ok, %Xandra.Page{} = page} <-
           XandraUtils.retrieve_page(conn, statement, params, consistency: consistency),
         {:ok, value} <- retrieve_path_count(page) do
      case value do
        0 ->
          {:ok, false}

        1 ->
          {:ok, true}
      end
    end
  end

  defp retrieve_path_count(page) do
    case Enum.to_list(page) do
      [] ->
        {:error, :property_not_set}

      [%{count: nil}] ->
        {:error, :undefined_property}

      [%{count: value}] ->
        {:ok, value}
    end
  end

  @spec fetch_last_path_update(
          String.t(),
          Device.device_id(),
          %InterfaceDescriptor{},
          %Mapping{},
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
    XandraUtils.run(
      realm,
      &do_fetch_last_path_update(&1, &2, device_id, interface_descriptor, mapping, path)
    )
  end

  defp do_fetch_last_path_update(
         conn,
         keyspace_name,
         device_id,
         interface_descriptor,
         mapping,
         path
       ) do
    # TODO: do not hardcode individual_properties here
    statement = """
    SELECT datetime_value, reception_timestamp, reception_timestamp_submillis
    FROM #{keyspace_name}.#{@individual_properties_table}
    WHERE device_id=:device_id AND interface_id=:interface_id
      AND endpoint_id=:endpoint_id AND path=:path
    """

    params = %{
      device_id: device_id,
      interface_id: interface_descriptor.interface_id,
      endpoint_id: mapping.endpoint_id,
      path: path
    }

    consistency = Consistency.device_info(:read)

    with {:ok, %Xandra.Page{} = page} <-
           XandraUtils.retrieve_page(conn, statement, params, consistency: consistency) do
      retrieve_last_path_update(page)
    end
  end

  defp retrieve_last_path_update(page) do
    case Enum.to_list(page) do
      [] ->
        {:error, :path_not_set}

      [columns] ->
        %{
          reception_timestamp: reception_timestamp,
          reception_timestamp_submillis: reception_timestamp_submillis,
          datetime_value: datetime_value
        } = columns

        if is_integer(reception_timestamp) and is_integer(datetime_value) do
          with {:ok, value_t} <- DateTime.from_unix(datetime_value, :millisecond),
               reception_unix =
                 reception_timestamp * 1000 + div(reception_timestamp_submillis || 0, 10),
               {:ok, reception_t} <- DateTime.from_unix(reception_unix, :microsecond) do
            {:ok, %{value_timestamp: value_t, reception_timestamp: reception_t}}
          end
        else
          {:error, :invalid_result}
        end
    end
  end
end
