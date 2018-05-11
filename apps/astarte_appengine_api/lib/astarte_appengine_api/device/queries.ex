#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2017-2018 Ispirata Srl
#

defmodule Astarte.AppEngine.API.Device.Queries do
  alias Astarte.AppEngine.API.Config
  alias Astarte.AppEngine.API.Device.DeviceNotFoundError
  alias Astarte.AppEngine.API.Device.InterfaceNotFoundError
  alias Astarte.Core.CQLUtils
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult
  require Logger

  def retrieve_interface_row!(client, interface, major_version) do
    interface_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT name, major_version, minor_version, interface_id, type, quality, flags, storage, storage_type, automaton_transitions, automaton_accepting_states FROM interfaces" <>
          " WHERE name=:name AND major_version=:major_version"
      )
      |> DatabaseQuery.put(:name, interface)
      |> DatabaseQuery.put(:major_version, major_version)

    interface_row =
      DatabaseQuery.call!(client, interface_query)
      |> DatabaseResult.head()

    if interface_row == :empty_dataset do
      Logger.warn(
        "Device.retrieve_interface_row: interface not found. This error here means that the device has an interface that is not installed."
      )

      raise InterfaceNotFoundError
    end

    interface_row
  end

  def interface_version!(client, device_id, interface) do
    device_introspection_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT introspection FROM devices WHERE device_id=:device_id")
      |> DatabaseQuery.put(:device_id, device_id)

    device_row =
      DatabaseQuery.call!(client, device_introspection_query)
      |> DatabaseResult.head()

    if device_row == :empty_dataset do
      raise DeviceNotFoundError
    end

    interface_tuple =
      device_row[:introspection]
      |> List.keyfind(interface, 0)

    case interface_tuple do
      {_interface_name, interface_major} ->
        interface_major

      nil ->
        # TODO: report device introspection here for debug purposes
        raise InterfaceNotFoundError
    end
  end

  def retrieve_interfaces_list!(client, device_id) do
    device_introspection_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT introspection FROM devices WHERE device_id=:device_id")
      |> DatabaseQuery.put(:device_id, device_id)

    device_row =
      DatabaseQuery.call!(client, device_introspection_query)
      |> DatabaseResult.head()

    if device_row == :empty_dataset do
      raise DeviceNotFoundError
    end

    for {interface_name, _interface_major} <- device_row[:introspection] do
      interface_name
    end
  end

  def retrieve_all_endpoint_ids_for_interface!(client, interface_id) do
    endpoints_with_type_statement = """
    SELECT value_type, endpoint_id
    FROM endpoints
    WHERE interface_id=:interface_id
    """

    endpoint_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(endpoints_with_type_statement)
      |> DatabaseQuery.put(:interface_id, interface_id)

    DatabaseQuery.call!(client, endpoint_query)
  end

  def prepare_get_property_statement(
        value_type,
        metadata,
        table_name,
        :multi_interface_individual_properties_dbtable
      ) do
    metadata_column =
      if metadata do
        ",metadata"
      else
        ""
      end

    # TODO: should we filter on path for performance reason?
    # TODO: probably we should sanitize also table_name: right now it is stored on database
    "SELECT path, #{Astarte.Core.CQLUtils.type_to_db_column_name(value_type)} #{metadata_column} FROM #{
      table_name
    }" <>
      " WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id;"
  end

  def prepare_get_individual_datastream_statement(
        value_type,
        metadata,
        table_name,
        :multi_interface_individual_datastream_dbtable,
        opts
      ) do
    metadata_column =
      if metadata do
        ",metadata"
      else
        ""
      end

    {since_statement, since_value} =
      cond do
        opts.since != nil ->
          {"AND value_timestamp >= :since", opts.since}

        opts.since_after != nil ->
          {"AND value_timestamp > :since", opts.since_after}

        opts.since == nil and opts.since_after == nil ->
          {"", nil}
      end

    {to_statement, to_value} =
      if opts.to != nil do
        {"AND value_timestamp < :to_timestamp", opts.to}
      else
        {"", nil}
      end

    query_limit = min(opts.limit, Config.max_results_limit())

    {limit_statement, limit_value} =
      cond do
        # Check the explicit user defined limit to know if we have to reorder data
        opts.limit != nil and since_value == nil ->
          {"ORDER BY value_timestamp DESC, reception_timestamp DESC, reception_timestamp_submillis DESC LIMIT :limit_nrows",
           query_limit}

        query_limit != nil ->
          {"LIMIT :limit_nrows", query_limit}

        true ->
          {"", nil}
      end

    query =
      if since_statement != "" do
        %{since: DateTime.to_unix(since_value, :milliseconds)}
      else
        %{}
      end

    query =
      if to_statement != "" do
        query
        |> Map.put(:to_timestamp, DateTime.to_unix(to_value, :milliseconds))
      else
        query
      end

    query =
      if limit_statement != "" do
        query
        |> Map.put(:limit_nrows, limit_value)
      else
        query
      end

    where_clause =
      " WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path #{
        since_statement
      } #{to_statement} #{limit_statement}"

    {
      "SELECT value_timestamp, reception_timestamp, reception_timestamp_submillis, #{
        CQLUtils.type_to_db_column_name(value_type)
      } #{metadata_column} FROM #{table_name} #{where_clause}",
      "SELECT count(value_timestamp, reception_timestamp, reception_timestamp_submillis) FROM #{
        table_name
      } #{where_clause}",
      query
    }
  end

  def retrieve_all_endpoint_paths!(client, device_id, interface_id, endpoint_id) do
    all_paths_statement = """
      SELECT path
      FROM individual_property
      WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id
    """

    all_paths_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(all_paths_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)

    DatabaseQuery.call!(client, all_paths_query)
  end

  # TODO Copy&pasted from data updater plant, make it a library
  def insert_value_into_db(
        db_client,
        :multi_interface_individual_properties_dbtable,
        device_id,
        interface_descriptor,
        endpoint_id,
        endpoint,
        path,
        value,
        timestamp
      ) do
    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "INSERT INTO #{interface_descriptor.storage} " <>
          "(device_id, interface_id, endpoint_id, path, reception_timestamp, #{
            CQLUtils.type_to_db_column_name(endpoint.value_type)
          }) " <>
          "VALUES (:device_id, :interface_id, :endpoint_id, :path, :reception_timestamp, :value);"
      )
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.put(:reception_timestamp, timestamp)
      |> DatabaseQuery.put(:reception_timestamp_submillis, 0)
      |> DatabaseQuery.put(:value, to_db_friendly_type(value))

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  # TODO Copy&pasted from data updater plant, make it a library
  def insert_value_into_db(
        db_client,
        :multi_interface_individual_datastream_dbtable,
        device_id,
        interface_descriptor,
        endpoint_id,
        endpoint,
        path,
        value,
        timestamp
      ) do
    # TODO: use received value_timestamp when needed
    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "INSERT INTO #{interface_descriptor.storage} " <>
          "(device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, #{
            CQLUtils.type_to_db_column_name(endpoint.value_type)
          }) " <>
          "VALUES (:device_id, :interface_id, :endpoint_id, :path, :value_timestamp, :reception_timestamp, :reception_timestamp_submillis, :value);"
      )
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.put(:value_timestamp, timestamp)
      |> DatabaseQuery.put(:reception_timestamp, timestamp)
      |> DatabaseQuery.put(:reception_timestamp_submillis, 0)
      |> DatabaseQuery.put(:value, to_db_friendly_type(value))

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  # TODO Copy&pasted from data updater plant, make it a library
  defp to_db_friendly_type(value) do
    value
  end

  def retrieve_extended_id(client, device_id) do
    extended_id_statement = "SELECT extended_id FROM devices WHERE device_id=:device_id"

    extended_id_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(extended_id_statement)
      |> DatabaseQuery.put(:device_id, device_id)

    with {:ok, result} <- DatabaseQuery.call(client, extended_id_query),
         [extended_id: extended_id] <- DatabaseResult.head(result) do
      {:ok, extended_id}
    else
      :empty_dataset ->
        {:error, :device_not_found}

      not_ok ->
        Logger.warn("Device.retrieve_extended_id: database error: #{inspect(not_ok)}")
        {:error, :database_error}
    end
  end

  def device_alias_to_device_id(client, device_alias) do
    device_id_statement =
      "SELECT object_uuid FROM names WHERE object_name = :device_alias AND object_type = 1;"

    device_id_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(device_id_statement)
      |> DatabaseQuery.put(:device_alias, device_alias)

    with {:ok, result} <- DatabaseQuery.call(client, device_id_query),
         [object_uuid: device_id] <- DatabaseResult.head(result) do
      {:ok, device_id}
    else
      :empty_dataset ->
        {:error, :device_not_found}

      not_ok ->
        Logger.warn("Device.device_alias_to_device_id: database error: #{inspect(not_ok)}")
        {:error, :database_error}
    end
  end

  def insert_alias(client, device_id, alias_tag, alias_value) do
    # TODO: Add  IF NOT EXISTS and batch queries together
    insert_alias_to_names_statement =
      "INSERT INTO names (object_name, object_type, object_uuid) VALUES (:alias, 1, :device_id);"

    insert_alias_to_names_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_alias_to_names_statement)
      |> DatabaseQuery.put(:alias, alias_value)
      |> DatabaseQuery.put(:device_id, device_id)

    insert_alias_to_device_statement =
      "UPDATE devices SET aliases[:alias_tag] = :alias WHERE device_id = :device_id;"

    insert_alias_to_device_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_alias_to_device_statement)
      |> DatabaseQuery.put(:alias_tag, alias_tag)
      |> DatabaseQuery.put(:alias, alias_value)
      |> DatabaseQuery.put(:device_id, device_id)

    # TODO: avoid to delete and insert again the same alias if it didn't change
    with :ok <- try_delete_alias(client, device_id, alias_tag),
         {:ok, _result} <- DatabaseQuery.call(client, insert_alias_to_names_query),
         {:ok, _result} <- DatabaseQuery.call(client, insert_alias_to_device_query) do
      :ok
    else
      {:error, :device_not_found} ->
        {:error, :device_not_found}

      not_ok ->
        Logger.warn("Device.insert_alias: database error: #{inspect(not_ok)}")
        {:error, :database_error}
    end
  end

  def delete_alias(client, device_id, alias_tag) do
    retrieve_aliases_statement = "SELECT aliases FROM devices WHERE device_id = :device_id;"

    retrieve_aliases_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(retrieve_aliases_statement)
      |> DatabaseQuery.put(:device_id, device_id)

    with {:ok, result} <- DatabaseQuery.call(client, retrieve_aliases_query),
         [aliases: aliases] <- DatabaseResult.head(result),
         {^alias_tag, alias_value} <-
           Enum.find(aliases || [], fn a -> match?({^alias_tag, _}, a) end) do
      # TODO: Add IF EXISTS and batch
      delete_alias_from_device_statement =
        "DELETE aliases[:alias_tag] FROM devices WHERE device_id = :device_id;"

      delete_alias_from_device_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(delete_alias_from_device_statement)
        |> DatabaseQuery.put(:alias_tag, alias_tag)
        |> DatabaseQuery.put(:device_id, device_id)

      delete_alias_from_names_statement =
        "DELETE FROM names WHERE object_name = :alias AND object_type = 1;"

      delete_alias_from_names_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(delete_alias_from_names_statement)
        |> DatabaseQuery.put(:alias, alias_value)
        |> DatabaseQuery.put(:device_id, device_id)

      with {:ok, _result} <- DatabaseQuery.call(client, delete_alias_from_device_query),
           {:ok, _result} <- DatabaseQuery.call(client, delete_alias_from_names_query) do
        :ok
      else
        not_ok ->
          Logger.warn("Device.delete_alias: database error: #{inspect(not_ok)}")
          {:error, :database_error}
      end
    else
      :empty_dataset ->
        {:error, :device_not_found}

      nil ->
        {:error, :alias_tag_not_found}

      not_ok ->
        Logger.warn("Device.delete_alias: database error: #{inspect(not_ok)}")
        {:error, :database_error}
    end
  end

  defp try_delete_alias(client, device_id, alias_tag) do
    case delete_alias(client, device_id, alias_tag) do
      :ok ->
        :ok

      {:error, :alias_tag_not_found} ->
        :ok

      not_ok ->
        not_ok
    end
  end
end
