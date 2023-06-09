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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Queries do
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.DataUpdaterPlant.Config
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
        Logger.warn("Database error: #{error_message}.")
        {:error, :database_error}

      {:error, reason} ->
        # DB Error
        Logger.warn("Failed with reason #{inspect(reason)}.")
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
        _reception_timestamp,
        _opts
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
        reception_timestamp,
        _opts
      ) do
    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "INSERT INTO #{interface_descriptor.storage} " <>
          "(device_id, interface_id, endpoint_id, path, reception_timestamp, #{CQLUtils.type_to_db_column_name(endpoint.value_type)}) " <>
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
        reception_timestamp,
        opts
      ) do
    ttl_string = get_ttl_string(opts)

    # TODO: use received value_timestamp when needed
    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "INSERT INTO #{interface_descriptor.storage} " <>
          "(device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, #{CQLUtils.type_to_db_column_name(endpoint.value_type)}) " <>
          "VALUES (:device_id, :interface_id, :endpoint_id, :path, :value_timestamp, :reception_timestamp, :reception_timestamp_submillis, :value) #{ttl_string};"
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
        reception_timestamp,
        opts
      ) do
    ttl_string = get_ttl_string(opts)

    # TODO: we should cache endpoints by interface_id
    endpoint_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT endpoint, value_type FROM endpoints WHERE interface_id=:interface_id;"
      )
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)

    endpoint_rows = DatabaseQuery.call!(db_client, endpoint_query)

    # TODO: we should also cache explicit_timestamp
    explicit_timestamp_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT explicit_timestamp FROM endpoints WHERE interface_id=:interface_id LIMIT 1;"
      )
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)

    [explicit_timestamp: explicit_timestamp] =
      DatabaseQuery.call!(db_client, explicit_timestamp_query)
      |> CQEx.Result.head()

    # FIXME: new atoms are created here, we should avoid this. We need to replace CQEx.
    column_atoms =
      Enum.reduce(endpoint_rows, %{}, fn endpoint, column_atoms_acc ->
        endpoint_name =
          endpoint[:endpoint]
          |> String.split("/")
          |> List.last()

        column_name = CQLUtils.endpoint_to_db_column_name(endpoint_name)

        Map.put(column_atoms_acc, endpoint_name, String.to_atom(column_name))
      end)

    {query_values, placeholders, query_columns} =
      Enum.reduce(value, {%{}, "", ""}, fn {obj_key, obj_value},
                                           {query_values_acc, placeholders_acc, query_acc} ->
        if column_atoms[obj_key] != nil do
          column_name = CQLUtils.endpoint_to_db_column_name(obj_key)

          db_value = to_db_friendly_type(obj_value)
          next_query_values_acc = Map.put(query_values_acc, column_atoms[obj_key], db_value)
          next_placeholders_acc = "#{placeholders_acc} :#{to_string(column_atoms[obj_key])},"
          next_query_acc = "#{query_acc} #{column_name}, "

          {next_query_values_acc, next_placeholders_acc, next_query_acc}
        else
          Logger.warn(
            "Unexpected object key #{inspect(obj_key)} with value #{inspect(obj_value)}."
          )

          query_values_acc
        end
      end)

    {query_columns, placeholders} =
      if explicit_timestamp do
        {"value_timestamp, #{query_columns}", ":value_timestamp, #{placeholders}"}
      else
        {query_columns, placeholders}
      end

    # TODO: use received value_timestamp when needed
    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "INSERT INTO #{interface_descriptor.storage} (device_id, path, #{query_columns} reception_timestamp, reception_timestamp_submillis) " <>
          "VALUES (:device_id, :path, #{placeholders} :reception_timestamp, :reception_timestamp_submillis) #{ttl_string};"
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

  defp get_ttl_string(opts) do
    with {:ok, value} when is_integer(value) <- Keyword.fetch(opts, :ttl) do
      "USING TTL #{to_string(value)}"
    else
      _any_error ->
        ""
    end
  end

  def insert_path_into_db(
        db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_datastream_dbtable} =
          interface_descriptor,
        mapping,
        path,
        value_timestamp,
        reception_timestamp,
        opts
      ) do
    insert_path(
      db_client,
      device_id,
      interface_descriptor,
      mapping,
      path,
      value_timestamp,
      reception_timestamp,
      opts
    )
  end

  def insert_path_into_db(
        db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :one_object_datastream_dbtable} = interface_descriptor,
        mapping,
        path,
        value_timestamp,
        reception_timestamp,
        opts
      ) do
    insert_path(
      db_client,
      device_id,
      interface_descriptor,
      mapping,
      path,
      value_timestamp,
      reception_timestamp,
      opts
    )
  end

  defp insert_path(
         db_client,
         device_id,
         interface_descriptor,
         endpoint,
         path,
         value_timestamp,
         reception_timestamp,
         opts
       ) do
    ttl_string = get_ttl_string(opts)

    # TODO: do not hardcode individual_properties here
    insert_statement = """
    INSERT INTO individual_properties
        (device_id, interface_id, endpoint_id, path,
        reception_timestamp, reception_timestamp_submillis, datetime_value)
    VALUES (:device_id, :interface_id, :endpoint_id, :path,
        :reception_timestamp, :reception_timestamp_submillis, :datetime_value) #{ttl_string}
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
    SELECT total_received_msgs, total_received_bytes, introspection,
           exchanged_bytes_by_interface, exchanged_msgs_by_interface
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

    introspection_map = convert_map_result(device_row[:introspection])

    initial_interface_exchanged_bytes =
      convert_map_result(device_row[:exchanged_bytes_by_interface])
      |> convert_tuple_keys()

    initial_interface_exchanged_msgs =
      convert_map_result(device_row[:exchanged_msgs_by_interface])
      |> convert_tuple_keys()

    %{
      introspection: introspection_map,
      total_received_msgs: device_row[:total_received_msgs],
      total_received_bytes: device_row[:total_received_bytes],
      initial_interface_exchanged_bytes: initial_interface_exchanged_bytes,
      initial_interface_exchanged_msgs: initial_interface_exchanged_msgs
    }
  end

  defp convert_map_result(nil), do: %{}
  defp convert_map_result(result) when is_list(result), do: Enum.into(result, %{})
  defp convert_map_result(result) when is_map(result), do: result

  # CQEx returns tuple keys as lists, convert them to tuples
  defp convert_tuple_keys(map) when is_map(map) do
    for {key, value} <- map, into: %{} do
      {List.to_tuple(key), value}
    end
  end

  def set_device_connected!(db_client, device_id, timestamp_ms, ip_address) do
    set_connection_info!(db_client, device_id, timestamp_ms, ip_address)

    ttl = heartbeat_interval_seconds() * 8
    refresh_device_connected!(db_client, device_id, ttl)
  end

  def maybe_refresh_device_connected!(db_client, device_id) do
    with {:ok, remaining_ttl} <- get_connected_remaining_ttl(db_client, device_id) do
      if remaining_ttl < heartbeat_interval_seconds() * 2 do
        Logger.debug("Refreshing connected status", tag: "refresh_device_connected")
        write_ttl = heartbeat_interval_seconds() * 8
        refresh_device_connected!(db_client, device_id, write_ttl)
      else
        :ok
      end
    end
  end

  defp heartbeat_interval_seconds do
    Config.device_heartbeat_interval_ms!() |> div(1000)
  end

  defp set_connection_info!(db_client, device_id, timestamp_ms, ip_address) do
    device_update_statement = """
    UPDATE devices
    SET last_connection=:last_connection, last_seen_ip=:last_seen_ip
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

  defp refresh_device_connected!(db_client, device_id, ttl) do
    refresh_connected_statement = """
    UPDATE devices
    USING TTL #{ttl}
    SET connected=true
    WHERE device_id=:device_id
    """

    refresh_connected_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(refresh_connected_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.consistency(:local_quorum)

    DatabaseQuery.call!(db_client, refresh_connected_query)
  end

  defp get_connected_remaining_ttl(db_client, device_id) do
    fetch_connected_ttl_statement = """
    SELECT TTL(connected)
    FROM devices
    WHERE device_id=:device_id
    """

    fetch_connected_ttl_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(fetch_connected_ttl_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(db_client, fetch_connected_ttl_query),
         ["ttl(connected)": ttl] when is_integer(ttl) <- DatabaseResult.head(result) do
      {:ok, ttl}
    else
      :empty_dataset ->
        {:error, :device_not_found}

      ["ttl(connected)": nil] ->
        {:ok, 0}

      %{acc: _, msg: error_message} ->
        Logger.warn("Database error: #{error_message}.")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("Database error while retrieving property: #{inspect(reason)}.")
        {:error, :database_error}
    end
  end

  def set_device_disconnected!(
        db_client,
        device_id,
        timestamp_ms,
        total_received_msgs,
        total_received_bytes,
        interface_exchanged_msgs,
        interface_exchanged_bytes
      ) do
    device_update_statement = """
    UPDATE devices
    SET connected=false,
        last_disconnection=:last_disconnection,
        total_received_msgs=:total_received_msgs,
        total_received_bytes=:total_received_bytes,
        exchanged_bytes_by_interface=exchanged_bytes_by_interface + :exchanged_bytes_by_interface,
        exchanged_msgs_by_interface=exchanged_msgs_by_interface + :exchanged_msgs_by_interface
    WHERE device_id=:device_id
    """

    device_update_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(device_update_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:last_disconnection, timestamp_ms)
      |> DatabaseQuery.put(:total_received_msgs, total_received_msgs)
      |> DatabaseQuery.put(:total_received_bytes, total_received_bytes)
      |> DatabaseQuery.put(:exchanged_bytes_by_interface, interface_exchanged_bytes)
      |> DatabaseQuery.put(:exchanged_msgs_by_interface, interface_exchanged_msgs)
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
        Logger.warn("Database error: #{error_message}.")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("Failed with reason #{inspect(reason)}.")
        {:error, :database_error}
    end
  end

  def get_device_groups(db_client, device_id) do
    groups_statement = """
    SELECT groups
    FROM devices
    WHERE device_id=:device_id
    """

    groups_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(groups_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(db_client, groups_query),
         [groups: groups] when is_list(groups) <- DatabaseResult.head(result) do
      {:ok, :proplists.get_keys(groups)}
    else
      [groups: nil] ->
        {:ok, []}

      %{acc: _, msg: error_message} ->
        Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("Failed with reason #{inspect(reason)}.", tag: "db_error")
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
          "Database error: cannot register device-interface pair, reason: #{inspect(reason)}."
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
          "Database error: cannot unregister device-interface pair: #{inspect(reason)}."
        )

        {:error, reason}
    end
  end

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
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Database error, reason: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  defp to_db_friendly_type(array) when is_list(array) do
    # If we have an array, we convert its elements to a db friendly type
    Enum.map(array, &to_db_friendly_type/1)
  end

  defp to_db_friendly_type(%DateTime{} = datetime) do
    DateTime.to_unix(datetime, :millisecond)
  end

  defp to_db_friendly_type({_subtype, bin}) do
    bin
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
    "SELECT path, #{Astarte.Core.CQLUtils.type_to_db_column_name(value_type)} #{metadata_column} FROM #{table_name}" <>
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

  def fetch_datastream_maximum_storage_retention(client) do
    maximum_storage_retention_statement = """
    SELECT blobAsInt(value)
    FROM kv_store
    WHERE group='realm_config' AND key='datastream_maximum_storage_retention'
    """

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(maximum_storage_retention_statement)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, res} <- DatabaseQuery.call(client, query),
         ["system.blobasint(value)": maximum_storage_retention] <- DatabaseResult.head(res) do
      {:ok, maximum_storage_retention}
    else
      :empty_dataset ->
        {:ok, nil}

      %{acc: _, msg: error_message} ->
        Logger.warn("Database error: #{error_message}.")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("Failed with reason: #{inspect(reason)}.")
        {:error, :database_error}
    end
  end

  def fetch_path_expiry(db_client, device_id, interface_descriptor, %Mapping{} = mapping, path)
      when is_binary(device_id) and is_binary(path) do
    # TODO: do not hardcode individual_properties here
    fetch_property_value_statement = """
    SELECT TTL(datetime_value)
    FROM individual_properties
    WHERE device_id=:device_id AND interface_id=:interface_id
      AND endpoint_id=:endpoint_id AND path=:path
    """

    fetch_property_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(fetch_property_value_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
      |> DatabaseQuery.put(:endpoint_id, mapping.endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(db_client, fetch_property_query),
         ["ttl(datetime_value)": ttl] when is_integer(ttl) <- DatabaseResult.head(result) do
      expiry_datetime =
        DateTime.utc_now()
        |> DateTime.to_unix()
        |> :erlang.+(ttl)
        |> DateTime.from_unix!()

      {:ok, expiry_datetime}
    else
      :empty_dataset ->
        {:error, :property_not_set}

      ["ttl(datetime_value)": nil] ->
        {:ok, :no_expiry}

      %{acc: _, msg: error_message} ->
        Logger.warn("Database error: #{error_message}.")
        {:error, :database_error}

      {:error, reason} ->
        Logger.warn("Database error while retrieving property: #{inspect(reason)}.")
        {:error, :database_error}
    end
  end
end
