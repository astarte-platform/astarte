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
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.Queries do
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult
  require Logger

  def query_simple_triggers!(db_client, object_id, object_type_int) do
    simple_triggers_statement = """
    SELECT simple_trigger_id, parent_trigger_id, trigger_data, trigger_target
    FROM simple_triggers
    WHERE object_id=:object_id AND object_type=:object_type_int
    """

    simple_triggers_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(simple_triggers_statement)
      |> DatabaseQuery.put(:object_id, object_id)
      |> DatabaseQuery.put(:object_type_int, object_type_int)

    DatabaseQuery.call!(db_client, simple_triggers_query)
  end

  def query_all_endpoint_paths!(db_client, device_id, interface_descriptor, endpoint_id) do
    all_paths_statement = """
    SELECT path FROM #{interface_descriptor.storage}
    WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id
    """

    all_paths_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(all_paths_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)

    DatabaseQuery.call!(db_client, all_paths_query)
  end

  def set_pending_empty_cache(db_client, device_id, pending_empty_cache) do
    pending_empty_cache_statement = """
    UPDATE devices
    SET pending_empty_cache = :pending_empty_cache
    WHERE device_id = :device_id
    """

    update_pending =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(pending_empty_cache_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:pending_empty_cache, pending_empty_cache)

    with {:ok, _result} <- DatabaseQuery.call(db_client, update_pending) do
      :ok
    else
      %{acc: _, msg: error_message} ->
        Logger.warn("set_pending_empty_cache: database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        # DB Error
        Logger.warn("set_pending_empty_cache: failed with reason #{inspect(reason)}")
        {:error, :database_error}
    end
  end

  def insert_value_into_db(
        db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_properties_dbtable} =
          interface_descriptor,
        endpoint,
        path,
        nil,
        _value_timestamp,
        _reception_timestamp
      ) do
    if endpoint.allow_unset == false do
      Logger.warn("Tried to unset value on allow_unset=false mapping.")
      # TODO: should we handle this situation?
    end

    # TODO: :reception_timestamp_submillis is just a place holder right now
    unset_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "DELETE FROM #{interface_descriptor.storage} WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path"
      )
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint.endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.consistency(insert_consistency(interface_descriptor, endpoint))

    DatabaseQuery.call!(db_client, unset_query)

    :ok
  end

  def insert_value_into_db(
        db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_properties_dbtable} =
          interface_descriptor,
        endpoint,
        path,
        value,
        _value_timestamp,
        reception_timestamp
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
      |> DatabaseQuery.put(:endpoint_id, endpoint.endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.put(:reception_timestamp, div(reception_timestamp, 10000))
      |> DatabaseQuery.put(:reception_timestamp_submillis, rem(reception_timestamp, 10000))
      |> DatabaseQuery.put(:value, to_db_friendly_type(value))
      |> DatabaseQuery.consistency(insert_consistency(interface_descriptor, endpoint))

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  def insert_value_into_db(
        db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_datastream_dbtable} =
          interface_descriptor,
        endpoint,
        path,
        value,
        value_timestamp,
        reception_timestamp
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
      |> DatabaseQuery.put(:endpoint_id, endpoint.endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.put(:value_timestamp, value_timestamp)
      |> DatabaseQuery.put(:reception_timestamp, div(reception_timestamp, 10000))
      |> DatabaseQuery.put(:reception_timestamp_submillis, rem(reception_timestamp, 10000))
      |> DatabaseQuery.put(:value, to_db_friendly_type(value))
      |> DatabaseQuery.consistency(insert_consistency(interface_descriptor, endpoint))

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  def insert_value_into_db(
        db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :one_object_datastream_dbtable} = interface_descriptor,
        _endpoint,
        path,
        value,
        value_timestamp,
        reception_timestamp
      ) do
    # TODO: we should cache endpoints by interface_id
    endpoint_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT endpoint, value_type FROM endpoints WHERE interface_id=:interface_id;"
      )
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)

    endpoint_rows = DatabaseQuery.call!(db_client, endpoint_query)

    # FIXME: new atoms are created here, we should avoid this. We need to fix our BSON decoder before, and to understand better CQEx code.
    column_atoms =
      Enum.reduce(endpoint_rows, %{}, fn endpoint, column_atoms_acc ->
        endpoint_name =
          endpoint[:endpoint]
          |> String.split("/")
          |> List.last()

        column_name = CQLUtils.endpoint_to_db_column_name(endpoint_name)

        Map.put(column_atoms_acc, String.to_atom(endpoint_name), String.to_atom(column_name))
      end)

    {query_values, placeholders, query_columns} =
      Enum.reduce(value, {%{}, "", ""}, fn {obj_key, obj_value},
                                           {query_values_acc, placeholders_acc, query_acc} ->
        if column_atoms[obj_key] != nil do
          column_name = CQLUtils.endpoint_to_db_column_name(to_string(obj_key))

          db_value = to_db_friendly_type(obj_value)
          next_query_values_acc = Map.put(query_values_acc, column_atoms[obj_key], db_value)
          next_placeholders_acc = "#{placeholders_acc} :#{to_string(column_atoms[obj_key])},"
          next_query_acc = "#{query_acc} #{column_name}, "

          {next_query_values_acc, next_placeholders_acc, next_query_acc}
        else
          Logger.warn(
            "Unexpected object key #{inspect(obj_key)} with value #{inspect(obj_value)}"
          )

          query_values_acc
        end
      end)

    # TODO: use received value_timestamp when needed
    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "INSERT INTO #{interface_descriptor.storage} (device_id, path, #{query_columns} reception_timestamp, reception_timestamp_submillis) " <>
          "VALUES (:device_id, :path, #{placeholders} :reception_timestamp, :reception_timestamp_submillis);"
      )
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.put(:value_timestamp, value_timestamp)
      |> DatabaseQuery.put(:reception_timestamp, div(reception_timestamp, 10000))
      |> DatabaseQuery.put(:reception_timestamp_submillis, rem(reception_timestamp, 10000))
      |> DatabaseQuery.merge(query_values)

    # TODO: |> DatabaseQuery.consistency(insert_consistency(interface_descriptor, endpoint))

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  def insert_path_into_db(
        db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_datastream_dbtable} =
          interface_descriptor,
        mapping,
        path,
        value_timestamp,
        reception_timestamp
      ) do
    insert_path(
      db_client,
      device_id,
      interface_descriptor,
      mapping,
      path,
      value_timestamp,
      reception_timestamp
    )
  end

  def insert_path_into_db(
        db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :one_object_datastream_dbtable} = interface_descriptor,
        mapping,
        path,
        value_timestamp,
        reception_timestamp
      ) do
    insert_path(
      db_client,
      device_id,
      interface_descriptor,
      mapping,
      path,
      value_timestamp,
      reception_timestamp
    )
  end

  defp insert_path(
         db_client,
         device_id,
         interface_descriptor,
         endpoint,
         path,
         value_timestamp,
         reception_timestamp
       ) do
    # TODO: do not hardcode individual_properties here
    insert_statement = """
    INSERT INTO individual_properties
        (device_id, interface_id, endpoint_id, path,
        reception_timestamp, reception_timestamp_submillis, datetime_value)
    VALUES (:device_id, :interface_id, :endpoint_id, :path,
        :reception_timestamp, :reception_timestamp_submillis, :datetime_value)
    """

    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint.endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.put(:reception_timestamp, div(reception_timestamp, 10000))
      |> DatabaseQuery.put(:reception_timestamp_submillis, rem(reception_timestamp, 10000))
      |> DatabaseQuery.put(:datetime_value, value_timestamp)
      |> DatabaseQuery.consistency(path_consistency(interface_descriptor, endpoint))

    with {:ok, %CQEx.Result.Empty{}} <- DatabaseQuery.call(db_client, insert_query) do
      :ok
    else
      {:error, reason} ->
        Logger.warn("Error while upserting path: #{path} (reason: #{inspect(reason)}).")
        {:error, :database_error}
    end
  end

  def delete_property_from_db(state, db_client, interface_descriptor, endpoint_id, path) do
    delete_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "DELETE FROM #{interface_descriptor.storage} WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path;"
      )
      |> DatabaseQuery.put(:device_id, state.device_id)
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, path)

    # TODO: |> DatabaseQuery.consistency(insert_consistency(interface_descriptor, endpoint))

    DatabaseQuery.call!(db_client, delete_query)
    :ok
  end

  def retrieve_device_stats_and_introspection!(db_client, device_id) do
    stats_and_introspection_statement = """
    SELECT total_received_msgs, total_received_bytes, introspection
    FROM devices
    WHERE device_id=:device_id
    """

    device_row_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(stats_and_introspection_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.consistency(:local_quorum)

    device_row =
      DatabaseQuery.call!(db_client, device_row_query)
      |> DatabaseResult.head()

    introspection_map =
      case device_row[:introspection] do
        :null ->
          %{}

        nil ->
          %{}

        result ->
          Enum.into(result, %{})
      end

    %{
      introspection: introspection_map,
      total_received_msgs: device_row[:total_received_msgs],
      total_received_bytes: device_row[:total_received_bytes]
    }
  end

  def set_device_connected!(db_client, device_id, timestamp_ms, ip_address) do
    device_update_statement = """
    UPDATE devices
    SET connected=true, last_connection=:last_connection, last_seen_ip=:last_seen_ip
    WHERE device_id=:device_id
    """

    device_update_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(device_update_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:last_connection, timestamp_ms)
      |> DatabaseQuery.put(:last_seen_ip, ip_address)
      |> DatabaseQuery.consistency(:local_quorum)

    DatabaseQuery.call!(db_client, device_update_query)
  end

  def set_device_disconnected!(
        db_client,
        device_id,
        timestamp_ms,
        total_received_msgs,
        total_received_bytes
      ) do
    device_update_statement = """
    UPDATE devices
    SET connected=false,
        last_disconnection=:last_disconnection,
        total_received_msgs=:total_received_msgs,
        total_received_bytes=:total_received_bytes
    WHERE device_id=:device_id
    """

    device_update_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(device_update_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:last_disconnection, timestamp_ms)
      |> DatabaseQuery.put(:total_received_msgs, total_received_msgs)
      |> DatabaseQuery.put(:total_received_bytes, total_received_bytes)
      |> DatabaseQuery.consistency(:local_quorum)

    DatabaseQuery.call!(db_client, device_update_query)
  end

  def fetch_device_introspection_minors(db_client, device_id) do
    introspection_minor_statement = """
    SELECT introspection_minor
    FROM devices
    WHERE device_id=:device_id
    """

    introspection_minor_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(introspection_minor_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(db_client, introspection_minor_query),
         [introspection_minor: introspection_minors] when is_list(introspection_minors) <-
           DatabaseResult.head(result) do
      {:ok, Enum.into(introspection_minors, %{})}
    else
      [introspection_minor: nil] ->
        {:ok, %{}}

      %{acc: _, msg: error_message} ->
        Logger.warn("fetch_device_introspection_minors: database error: #{error_message}")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("fetch_device_introspection_minors: failed with reason #{inspect(reason)}")
        {:error, :database_error}
    end
  end

  def update_device_introspection!(db_client, device_id, introspection, introspection_minor) do
    introspection_update_statement = """
    UPDATE devices
    SET introspection=:introspection, introspection_minor=:introspection_minor
    WHERE device_id=:device_id
    """

    introspection_update_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(introspection_update_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:introspection, introspection)
      |> DatabaseQuery.put(:introspection_minor, introspection_minor)
      |> DatabaseQuery.consistency(:quorum)

    DatabaseQuery.call!(db_client, introspection_update_query)
  end

  def add_old_interfaces(db_client, device_id, old_interfaces) do
    old_introspection_update_statement = """
    UPDATE devices
    SET old_introspection = old_introspection + :introspection
    WHERE device_id=:device_id
    """

    old_introspection_update_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(old_introspection_update_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:introspection, old_interfaces)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, _result} <- DatabaseQuery.call(db_client, old_introspection_update_query) do
      :ok
    end
  end

  def remove_old_interfaces(db_client, device_id, old_interfaces) do
    old_introspection_remove_statement = """
    UPDATE devices
    SET old_introspection = old_introspection - :old_interfaces
    WHERE device_id=:device_id
    """

    old_introspection_remove_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(old_introspection_remove_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:old_interfaces, old_interfaces)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, _result} <- DatabaseQuery.call(db_client, old_introspection_remove_query) do
      :ok
    end
  end

  def register_device_with_interface(db_client, device_id, interface_name, interface_major) do
    key_insert_statement = """
    INSERT INTO kv_store (group, key)
    VALUES (:group, :key)
    """

    major_str = "v#{Integer.to_string(interface_major)}"
    encoded_device_id = Device.encode_device_id(device_id)

    insert_device_by_interface_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(key_insert_statement)
      |> DatabaseQuery.put(:group, "devices-by-interface-#{interface_name}-#{major_str}")
      |> DatabaseQuery.put(:key, encoded_device_id)
      |> DatabaseQuery.consistency(:each_quorum)

    insert_to_with_data_on_interface =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(key_insert_statement)
      |> DatabaseQuery.put(
        :group,
        "devices-with-data-on-interface-#{interface_name}-#{major_str}"
      )
      |> DatabaseQuery.put(:key, encoded_device_id)
      |> DatabaseQuery.consistency(:each_quorum)

    with {:ok, _result} <- DatabaseQuery.call(db_client, insert_device_by_interface_query),
         {:ok, _result} <- DatabaseQuery.call(db_client, insert_to_with_data_on_interface) do
      :ok
    else
      {:error, reason} ->
        Logger.warn(
          "database error: cannot register device-interface pair, reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def unregister_device_with_interface(db_client, device_id, interface_name, interface_major) do
    key_delete_statement = """
    DELETE FROM kv_store
    WHERE group=:group AND key=:key
    """

    major_str = "v#{Integer.to_string(interface_major)}"
    encoded_device_id = Device.encode_device_id(device_id)

    delete_device_by_interface_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(key_delete_statement)
      |> DatabaseQuery.put(:group, "devices-by-interface-#{interface_name}-#{major_str}")
      |> DatabaseQuery.put(:key, encoded_device_id)
      |> DatabaseQuery.consistency(:each_quorum)

    with {:ok, _result} <- DatabaseQuery.call(db_client, delete_device_by_interface_query) do
      :ok
    else
      {:error, reason} ->
        Logger.warn(
          "database error: cannot unregister device-interface pair, reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp to_db_friendly_type(%Bson.UTC{ms: ms}) do
    ms
  end

  defp to_db_friendly_type(value) do
    value
  end

  def retrieve_endpoint_values(client, device_id, interface_descriptor, mapping) do
    query_statement =
      prepare_get_property_statement(
        mapping.value_type,
        false,
        interface_descriptor.storage,
        interface_descriptor.storage_type
      )

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(query_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
      |> DatabaseQuery.put(:endpoint_id, mapping.endpoint_id)

    DatabaseQuery.call!(client, query)
  end

  defp prepare_get_property_statement(
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

  defp path_consistency(_interface_descriptor, %Mapping{reliability: :unreliable} = _mapping) do
    :one
  end

  defp path_consistency(_interface_descriptor, _mapping) do
    :local_quorum
  end

  defp insert_consistency(%InterfaceDescriptor{type: :properties}, _mapping) do
    :quorum
  end

  defp insert_consistency(%InterfaceDescriptor{type: :datastream}, %Mapping{
         reliability: :guaranteed,
         retention: :stored
       }) do
    :local_quorum
  end

  defp insert_consistency(_interface_descriptor, %Mapping{reliability: :unreliable} = _mapping) do
    :any
  end

  defp insert_consistency(_interface_descriptor, _mapping) do
    :one
  end
end
