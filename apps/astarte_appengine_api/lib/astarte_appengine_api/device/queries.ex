#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

defmodule Astarte.AppEngine.API.Device.Queries do
  alias Astarte.AppEngine.API.Config
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.AppEngine.API.Device.InterfaceValuesOptions
  alias Astarte.AppEngine.API.Device.InterfaceInfo
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.ValueType
  alias Astarte.Core.StorageType
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult
  require CQEx
  require Logger

  def first_result_row(values) do
    DatabaseResult.head(values)
  end

  @spec retrieve_interfaces_list(:cqerl.client(), binary) ::
          {:ok, list(String.t())} | {:error, atom}
  def retrieve_interfaces_list(client, device_id) do
    device_introspection_statement = """
    SELECT introspection
    FROM devices
    WHERE device_id=:device_id
    """

    device_introspection_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(device_introspection_statement)
      |> DatabaseQuery.put(:device_id, device_id)

    with {:ok, result} <- DatabaseQuery.call(client, device_introspection_query),
         [introspection: introspection_or_nil] <- DatabaseResult.head(result) do
      introspection = introspection_or_nil || []

      interfaces_list =
        for {interface_name, _interface_major} <- introspection do
          interface_name
        end

      {:ok, interfaces_list}
    else
      :empty_dataset ->
        {:error, :device_not_found}

      {:error, reason} ->
        _ = Logger.warn("Database error: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
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

  def retrieve_all_endpoints_for_interface!(client, interface_id) do
    endpoints_with_type_statement = """
    SELECT value_type, endpoint
    FROM endpoints
    WHERE interface_id=:interface_id
    """

    endpoint_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(endpoints_with_type_statement)
      |> DatabaseQuery.put(:interface_id, interface_id)

    DatabaseQuery.call!(client, endpoint_query)
  end

  def retrieve_mapping(db_client, interface_id, endpoint_id) do
    mapping_statement = """
    SELECT endpoint, value_type, reliability, retention, database_retention_policy,
           database_retention_ttl, expiry, allow_unset, endpoint_id, interface_id,
           explicit_timestamp
    FROM endpoints
    WHERE interface_id=:interface_id AND endpoint_id=:endpoint_id
    """

    mapping_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(mapping_statement)
      |> DatabaseQuery.put(:interface_id, interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)

    DatabaseQuery.call!(db_client, mapping_query)
    |> DatabaseResult.head()
    |> Mapping.from_db_result!()
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
    "SELECT path, #{Astarte.Core.CQLUtils.type_to_db_column_name(value_type)} #{metadata_column} FROM #{table_name}" <>
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

    query_limit = min(opts.limit, Config.max_results_limit!())

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
        %{since: DateTime.to_unix(since_value, :millisecond)}
      else
        %{}
      end

    query =
      if to_statement != "" do
        query
        |> Map.put(:to_timestamp, DateTime.to_unix(to_value, :millisecond))
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
      " WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path #{since_statement} #{to_statement} #{limit_statement}"

    {
      "SELECT value_timestamp, reception_timestamp, reception_timestamp_submillis, #{CQLUtils.type_to_db_column_name(value_type)} #{metadata_column} FROM #{table_name} #{where_clause}",
      "SELECT count(value_timestamp) FROM #{table_name} #{where_clause}",
      query
    }
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

  def last_datastream_value!(
        client,
        device_id,
        interface_row,
        endpoint_row,
        endpoint_id,
        path,
        opts
      ) do
    {values_query_statement, _count_query_statement, q_params} =
      prepare_get_individual_datastream_statement(
        ValueType.from_int(endpoint_row[:value_type]),
        false,
        interface_row[:storage],
        StorageType.from_int(interface_row[:storage_type]),
        %{opts | limit: 1}
      )

    values_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(values_query_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_row[:interface_id])
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.merge(q_params)

    DatabaseQuery.call!(client, values_query)
    |> DatabaseResult.head()
  end

  def retrieve_all_endpoint_paths!(client, device_id, interface_id, endpoint_id) do
    all_paths_statement = """
      SELECT path
      FROM individual_properties
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
        %InterfaceDescriptor{storage_type: storage_type} = interface_descriptor,
        endpoint_id,
        path,
        value_timestamp,
        reception_timestamp,
        opts
      )
      when storage_type in [
             :multi_interface_individual_datastream_dbtable,
             :one_object_datastream_dbtable
           ] do
    # TODO: use received value_timestamp when needed
    # TODO: :reception_timestamp_submillis is just a place holder right now

    ttl_string = get_ttl_string(opts)

    insert_statement = """
    INSERT INTO individual_properties
        (device_id, interface_id, endpoint_id, path,
        reception_timestamp, reception_timestamp_submillis, datetime_value)
    VALUES (:device_id, :interface_id, :endpoint_id, :path, :reception_timestamp,
        :reception_timestamp_submillis, :datetime_value) #{ttl_string};
    """

    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.put(:reception_timestamp, div(reception_timestamp, 1000))
      |> DatabaseQuery.put(:reception_timestamp_submillis, rem(reception_timestamp, 100))
      |> DatabaseQuery.put(:datetime_value, value_timestamp)

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  # TODO Copy&pasted from data updater plant, make it a library
  def insert_value_into_db(
        db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_properties_dbtable} =
          interface_descriptor,
        _endpoint_id,
        endpoint,
        path,
        nil,
        _timestamp,
        _opts
      ) do
    if endpoint.allow_unset == false do
      _ =
        Logger.warn("Tried to unset value on allow_unset=false mapping.", tag: "unset_not_allowed")

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

    DatabaseQuery.call!(db_client, unset_query)

    :ok
  end

  # TODO Copy&pasted from data updater plant, make it a library
  def insert_value_into_db(
        db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_properties_dbtable} =
          interface_descriptor,
        endpoint_id,
        endpoint,
        path,
        value,
        timestamp,
        opts
      ) do
    ttl_string = get_ttl_string(opts)

    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("""
      INSERT INTO #{interface_descriptor.storage}
        (device_id, interface_id, endpoint_id, path, reception_timestamp,
          #{CQLUtils.type_to_db_column_name(endpoint.value_type)})
        VALUES (:device_id, :interface_id, :endpoint_id, :path, :reception_timestamp,
          :value) #{ttl_string};
      """)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.put(:reception_timestamp, div(timestamp, 1000))
      |> DatabaseQuery.put(:reception_timestamp_submillis, div(timestamp, 100))
      |> DatabaseQuery.put(:value, to_db_friendly_type(value))

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  # TODO Copy&pasted from data updater plant, make it a library
  def insert_value_into_db(
        db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_datastream_dbtable} =
          interface_descriptor,
        endpoint_id,
        endpoint,
        path,
        value,
        timestamp,
        opts
      ) do
    ttl_string = get_ttl_string(opts)

    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("""
      INSERT INTO #{interface_descriptor.storage}
        (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis,
          #{CQLUtils.type_to_db_column_name(endpoint.value_type)})
        VALUES (:device_id, :interface_id, :endpoint_id, :path, :value_timestamp, :reception_timestamp,
          :reception_timestamp_submillis, :value) #{ttl_string};
      """)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint.endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.put(:value_timestamp, div(timestamp, 1000))
      |> DatabaseQuery.put(:reception_timestamp, div(timestamp, 1000))
      |> DatabaseQuery.put(:reception_timestamp_submillis, rem(timestamp, 100))
      |> DatabaseQuery.put(:value, to_db_friendly_type(value))

    # TODO: |> DatabaseQuery.consistency(insert_consistency(interface_descriptor, endpoint))

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  # TODO Copy&pasted from data updater plant, make it a library
  def insert_value_into_db(
        db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :one_object_datastream_dbtable} = interface_descriptor,
        _endpoint_id,
        _mapping,
        path,
        value,
        timestamp,
        opts
      ) do
    ttl_string = get_ttl_string(opts)

    endpoint_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT endpoint, value_type FROM endpoints WHERE interface_id=:interface_id;"
      )
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)

    endpoint_rows = DatabaseQuery.call!(db_client, endpoint_query)

    explicit_timestamp_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(
        "SELECT explicit_timestamp FROM endpoints WHERE interface_id=:interface_id LIMIT 1;"
      )
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)

    [explicit_timestamp: explicit_timestamp] =
      DatabaseQuery.call!(db_client, explicit_timestamp_query)
      |> DatabaseResult.head()

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

    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("""
      INSERT INTO #{interface_descriptor.storage} (device_id, path, #{query_columns} reception_timestamp, reception_timestamp_submillis)
        VALUES (:device_id, :path, #{placeholders} :reception_timestamp, :reception_timestamp_submillis) #{ttl_string};
      """)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.put(:value_timestamp, div(timestamp, 1000))
      |> DatabaseQuery.put(:reception_timestamp, div(timestamp, 1000))
      |> DatabaseQuery.put(:reception_timestamp_submillis, rem(timestamp, 100))
      |> DatabaseQuery.merge(query_values)

    # TODO: |> DatabaseQuery.consistency(insert_consistency(interface_descriptor, endpoint))

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  # TODO Copy&pasted from data updater plant, make it a library
  defp to_db_friendly_type(array) when is_list(array) do
    # If we have an array, we convert its elements to a db friendly type
    Enum.map(array, &to_db_friendly_type/1)
  end

  defp to_db_friendly_type(%DateTime{} = datetime) do
    DateTime.to_unix(datetime, :millisecond)
  end

  defp to_db_friendly_type(value) do
    value
  end

  @device_status_columns_without_device_id """
    , aliases
    , introspection
    , introspection_minor
    , connected
    , last_connection
    , last_disconnection
    , first_registration
    , first_credentials_request
    , last_credentials_request_ip
    , last_seen_ip
    , attributes
    , total_received_msgs
    , total_received_bytes
    , exchanged_msgs_by_interface
    , exchanged_bytes_by_interface
    , groups
    , old_introspection
    , inhibit_credentials_request
  """

  defp device_status_row_to_device_status(row) do
    [
      device_id: device_id,
      aliases: aliases,
      introspection: introspection_major,
      introspection_minor: introspection_minor,
      connected: connected,
      last_connection: last_connection,
      last_disconnection: last_disconnection,
      first_registration: first_registration,
      first_credentials_request: first_credentials_request,
      last_credentials_request_ip: last_credentials_request_ip,
      last_seen_ip: last_seen_ip,
      attributes: attributes,
      total_received_msgs: total_received_msgs,
      total_received_bytes: total_received_bytes,
      exchanged_msgs_by_interface: exchanged_msgs_by_interface,
      exchanged_bytes_by_interface: exchanged_bytes_by_interface,
      groups: groups_proplist,
      old_introspection: old_introspection,
      inhibit_credentials_request: credentials_inhibited
    ] = row

    interface_msgs_map =
      exchanged_msgs_by_interface
      |> convert_map_result()
      |> convert_tuple_keys()

    interface_bytes_map =
      exchanged_bytes_by_interface
      |> convert_map_result()
      |> convert_tuple_keys()

    only_major_introspection =
      Enum.reduce(introspection_major || %{}, %{}, fn {interface, major}, acc ->
        Map.put(acc, interface, %InterfaceInfo{major: major})
      end)

    introspection =
      Enum.reduce(introspection_minor || %{}, %{}, fn {interface, minor}, acc ->
        with {:ok, major_item} <- Map.fetch(only_major_introspection, interface) do
          msgs = Map.get(interface_msgs_map, {interface, major_item.major}, 0)
          bytes = Map.get(interface_bytes_map, {interface, major_item.major}, 0)

          Map.put(acc, interface, %{
            major_item
            | minor: minor,
              exchanged_msgs: msgs,
              exchanged_bytes: bytes
          })
        else
          :error ->
            device = Device.encode_device_id(device_id)

            _ =
              Logger.error("Introspection has no minor version for interface. Corrupted entry?",
                interface: interface,
                device_id: device
              )

            acc
        end
      end)

    previous_interfaces =
      old_introspection
      |> convert_map_result()
      |> convert_tuple_keys()
      |> Enum.map(fn {{interface_name, major}, minor} ->
        msgs = Map.get(interface_msgs_map, {interface_name, major}, 0)
        bytes = Map.get(interface_bytes_map, {interface_name, major}, 0)

        %InterfaceInfo{
          name: interface_name,
          major: major,
          minor: minor,
          exchanged_msgs: msgs,
          exchanged_bytes: bytes
        }
      end)

    # groups_proplist could be nil, default to empty keyword list
    groups = :proplists.get_keys(groups_proplist || [])

    %DeviceStatus{
      id: Base.url_encode64(device_id, padding: false),
      aliases: Enum.into(aliases || [], %{}),
      introspection: introspection,
      connected: connected || false,
      last_connection: millis_or_null_to_datetime!(last_connection),
      last_disconnection: millis_or_null_to_datetime!(last_disconnection),
      first_registration: millis_or_null_to_datetime!(first_registration),
      first_credentials_request: millis_or_null_to_datetime!(first_credentials_request),
      last_credentials_request_ip: ip_or_null_to_string(last_credentials_request_ip),
      last_seen_ip: ip_or_null_to_string(last_seen_ip),
      attributes: Enum.into(attributes || [], %{}),
      credentials_inhibited: credentials_inhibited,
      total_received_msgs: total_received_msgs,
      total_received_bytes: total_received_bytes,
      previous_interfaces: previous_interfaces,
      groups: groups
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

  # TODO: copy&pasted from Device
  defp millis_or_null_to_datetime!(nil) do
    nil
  end

  # TODO: copy&pasted from Device
  defp millis_or_null_to_datetime!(millis) do
    DateTime.from_unix!(millis, :millisecond)
  end

  defp ip_or_null_to_string(nil) do
    nil
  end

  defp ip_or_null_to_string(ip) do
    ip
    |> :inet_parse.ntoa()
    |> to_string()
  end

  def retrieve_device_status(client, device_id) do
    device_statement = """
    SELECT device_id #{@device_status_columns_without_device_id}
    FROM devices
    WHERE device_id=:device_id
    """

    device_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(device_statement)
      |> DatabaseQuery.put(:device_id, device_id)

    with {:ok, result} <- DatabaseQuery.call(client, device_query),
         device_row when is_list(device_row) <- DatabaseResult.head(result) do
      {:ok, device_status_row_to_device_status(device_row)}
    else
      :empty_dataset ->
        {:error, :device_not_found}

      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Database error, reason: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  defp execute_devices_list_query(client, limit, retrieve_details, previous_token) do
    retrieve_details_string =
      if retrieve_details do
        @device_status_columns_without_device_id
      else
        ""
      end

    previous_token =
      case previous_token do
        nil ->
          # This is -2^63, that is the lowest 64 bit integer
          -9_223_372_036_854_775_808

        first ->
          first + 1
      end

    devices_list_statement = """
    SELECT TOKEN(device_id), device_id #{retrieve_details_string}
    FROM devices
    WHERE TOKEN(device_id) >= :previous_token LIMIT #{Integer.to_string(limit)};
    """

    devices_list_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(devices_list_statement)
      |> DatabaseQuery.put(:previous_token, previous_token)

    DatabaseQuery.call(client, devices_list_query)
  end

  def retrieve_devices_list(client, limit, retrieve_details, previous_token) do
    with {:ok, result} <-
           execute_devices_list_query(client, limit, retrieve_details, previous_token) do
      {devices_list, count, last_token} =
        Enum.reduce(result, {[], 0, nil}, fn row, {devices_acc, count, _last_seen_token} ->
          {device, token} =
            if retrieve_details do
              [{:"system.token(device_id)", token} | device_status_row] = row
              {device_status_row_to_device_status(device_status_row), token}
            else
              ["system.token(device_id)": token, device_id: device_id] = row
              {Base.url_encode64(device_id, padding: false), token}
            end

          {[device | devices_acc], count + 1, token}
        end)

      if count < limit do
        {:ok, %DevicesList{devices: Enum.reverse(devices_list)}}
      else
        {:ok, %DevicesList{devices: Enum.reverse(devices_list), last_token: last_token}}
      end
    else
      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Database error, reason: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def device_alias_to_device_id(client, device_alias) do
    device_id_statement = """
    SELECT object_uuid
    FROM names
    WHERE object_name = :device_alias AND object_type = 1
    """

    device_id_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(device_id_statement)
      |> DatabaseQuery.put(:device_alias, device_alias)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(client, device_id_query),
         [object_uuid: device_id] <- DatabaseResult.head(result) do
      {:ok, device_id}
    else
      :empty_dataset ->
        {:error, :device_not_found}

      not_ok ->
        _ = Logger.warn("Database error: #{inspect(not_ok)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def insert_attribute(client, device_id, attribute_key, attribute_value) do
    insert_attribute_statement = """
    UPDATE devices
    SET attributes[:attribute_key] = :attribute_value
    WHERE device_id = :device_id
    """

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_attribute_statement)
      |> DatabaseQuery.put(:attribute_key, attribute_key)
      |> DatabaseQuery.put(:attribute_value, attribute_value)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.consistency(:each_quorum)

    with {:ok, _result} <- DatabaseQuery.call(client, query) do
      :ok
    else
      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Database error, reason: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def delete_attribute(client, device_id, attribute_key) do
    retrieve_attribute_statement = """
    SELECT attributes FROM devices WHERE device_id = :device_id
    """

    retrieve_attribute_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(retrieve_attribute_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(client, retrieve_attribute_query),
         [attributes: attributes] <- DatabaseResult.head(result),
         {^attribute_key, _attribute_value} <-
           Enum.find(attributes || [], fn m -> match?({^attribute_key, _}, m) end) do
      delete_attribute_statement = """
        DELETE attributes[:attribute_key]
        FROM devices
        WHERE device_id = :device_id
      """

      delete_attribute_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(delete_attribute_statement)
        |> DatabaseQuery.put(:attribute_key, attribute_key)
        |> DatabaseQuery.put(:device_id, device_id)
        |> DatabaseQuery.consistency(:each_quorum)

      case DatabaseQuery.call(client, delete_attribute_query) do
        {:ok, _result} ->
          :ok

        %{acc: _, msg: error_message} ->
          _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
          {:error, :database_error}

        {:error, reason} ->
          _ = Logger.warn("Database error, reason: #{inspect(reason)}.", tag: "db_error")
          {:error, :database_error}
      end
    else
      nil ->
        {:error, :attribute_key_not_found}

      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Database error, reason: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def insert_alias(client, device_id, alias_tag, alias_value) do
    insert_alias_to_names_statement = """
    INSERT INTO names
    (object_name, object_type, object_uuid)
    VALUES (:alias, 1, :device_id)
    """

    insert_alias_to_names_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_alias_to_names_statement)
      |> DatabaseQuery.put(:alias, alias_value)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.consistency(:each_quorum)
      |> DatabaseQuery.convert()

    insert_alias_to_device_statement = """
    UPDATE devices
    SET aliases[:alias_tag] = :alias
    WHERE device_id = :device_id
    """

    insert_alias_to_device_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_alias_to_device_statement)
      |> DatabaseQuery.put(:alias_tag, alias_tag)
      |> DatabaseQuery.put(:alias, alias_value)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.consistency(:each_quorum)
      |> DatabaseQuery.convert()

    insert_batch =
      CQEx.cql_query_batch(
        consistency: :each_quorum,
        mode: :logged,
        queries: [insert_alias_to_names_query, insert_alias_to_device_query]
      )

    with {:existing, {:error, :device_not_found}} <-
           {:existing, device_alias_to_device_id(client, alias_value)},
         :ok <- try_delete_alias(client, device_id, alias_tag),
         {:ok, _result} <- DatabaseQuery.call(client, insert_batch) do
      :ok
    else
      {:existing, {:ok, _device_uuid}} ->
        {:error, :alias_already_in_use}

      {:existing, {:error, reason}} ->
        {:error, reason}

      {:error, :device_not_found} ->
        {:error, :device_not_found}

      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Database error, reason: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def delete_alias(client, device_id, alias_tag) do
    retrieve_aliases_statement = """
    SELECT aliases
    FROM devices
    WHERE device_id = :device_id
    """

    retrieve_aliases_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(retrieve_aliases_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.consistency(:quorum)

    with {:ok, result} <- DatabaseQuery.call(client, retrieve_aliases_query),
         [aliases: aliases] <- DatabaseResult.head(result),
         {^alias_tag, alias_value} <-
           Enum.find(aliases || [], fn a -> match?({^alias_tag, _}, a) end),
         {:check, {:ok, ^device_id}} <- {:check, device_alias_to_device_id(client, alias_value)} do
      delete_alias_from_device_statement = """
      DELETE aliases[:alias_tag]
      FROM devices
      WHERE device_id = :device_id
      """

      delete_alias_from_device_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(delete_alias_from_device_statement)
        |> DatabaseQuery.put(:alias_tag, alias_tag)
        |> DatabaseQuery.put(:device_id, device_id)
        |> DatabaseQuery.consistency(:each_quorum)
        |> DatabaseQuery.convert()

      delete_alias_from_names_statement = """
      DELETE FROM names
      WHERE object_name = :alias AND object_type = 1
      """

      delete_alias_from_names_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(delete_alias_from_names_statement)
        |> DatabaseQuery.put(:alias, alias_value)
        |> DatabaseQuery.put(:device_id, device_id)
        |> DatabaseQuery.consistency(:each_quorum)
        |> DatabaseQuery.convert()

      delete_batch =
        CQEx.cql_query_batch(
          consistency: :each_quorum,
          mode: :logged,
          queries: [delete_alias_from_device_query, delete_alias_from_names_query]
        )

      with {:ok, _result} <- DatabaseQuery.call(client, delete_batch) do
        :ok
      else
        %{acc: _, msg: error_message} ->
          _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
          {:error, :database_error}

        {:error, reason} ->
          _ = Logger.warn("Database error, reason: #{inspect(reason)}.", tag: "db_error")
          {:error, :database_error}
      end
    else
      {:check, _} ->
        _ =
          Logger.error("Inconsistent alias for #{alias_tag}.",
            device_id: device_id,
            tag: "inconsistent_alias"
          )

        {:error, :database_error}

      :empty_dataset ->
        {:error, :device_not_found}

      nil ->
        {:error, :alias_tag_not_found}

      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Database error, reason: #{inspect(reason)}.", tag: "db_error")
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

  def set_inhibit_credentials_request(client, device_id, inhibit_credentials_request) do
    statement = """
    UPDATE devices
    SET inhibit_credentials_request = :inhibit_credentials_request
    WHERE device_id = :device_id
    """

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(statement)
      |> DatabaseQuery.put(:inhibit_credentials_request, inhibit_credentials_request)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.consistency(:each_quorum)

    with {:ok, _result} <- DatabaseQuery.call(client, query) do
      :ok
    else
      %{acc: _, msg: error_message} ->
        _ = Logger.warn("Database error: #{error_message}.", tag: "db_error")
        {:error, :database_error}

      {:error, reason} ->
        _ = Logger.warn("Update failed, reason: #{inspect(reason)}.", tag: "db_error")
        {:error, :database_error}
    end
  end

  def retrieve_object_datastream_values(client, device_id, interface_row, path, columns, opts) do
    timestamp_column =
      if opts.explicit_timestamp do
        "value_timestamp"
      else
        "reception_timestamp"
      end

    {since_statement, since_value} =
      cond do
        opts.since != nil ->
          {"AND #{timestamp_column} >= :since", opts.since}

        opts.since_after != nil ->
          {"AND #{timestamp_column} > :since", opts.since_after}

        opts.since == nil and opts.since_after == nil ->
          {"", nil}
      end

    {to_statement, to_value} =
      if opts.to != nil do
        {"AND #{timestamp_column} < :to_timestamp", opts.to}
      else
        {"", nil}
      end

    query_limit = min(opts.limit, Config.max_results_limit!())

    {limit_statement, limit_value} =
      cond do
        # Check the explicit user defined limit to know if we have to reorder data
        opts.limit != nil and since_value == nil ->
          {"ORDER BY #{timestamp_column} DESC LIMIT :limit_nrows", query_limit}

        query_limit != nil ->
          {"LIMIT :limit_nrows", query_limit}

        true ->
          {"", nil}
      end

    where_clause =
      "WHERE device_id=:device_id #{since_statement} AND path=:path #{to_statement} #{limit_statement} ;"

    values_query_statement =
      "SELECT #{columns} #{timestamp_column} FROM #{interface_row[:storage]} #{where_clause};"

    values_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(values_query_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:path, path)

    values_query =
      if since_statement != "" do
        values_query
        |> DatabaseQuery.put(:since, DateTime.to_unix(since_value, :millisecond))
      else
        values_query
      end

    values_query =
      if to_statement != "" do
        values_query
        |> DatabaseQuery.put(:to_timestamp, DateTime.to_unix(to_value, :millisecond))
      else
        values_query
      end

    values_query =
      if limit_statement != "" do
        values_query
        |> DatabaseQuery.put(:limit_nrows, limit_value)
      else
        values_query
      end

    values = DatabaseQuery.call!(client, values_query)

    count_query_statement =
      "SELECT count(#{timestamp_column}) FROM #{interface_row[:storage]} #{where_clause} ;"

    count_query =
      values_query
      |> DatabaseQuery.statement(count_query_statement)

    count = get_results_count(client, count_query, opts)

    {:ok, count, values}
  end

  def get_results_count(_client, _count_query, %InterfaceValuesOptions{downsample_to: nil}) do
    # Count will be ignored since there's no downsample_to
    nil
  end

  def get_results_count(client, count_query, opts) do
    with {:ok, result} <- DatabaseQuery.call(client, count_query),
         [{_count_key, count}] <- DatabaseResult.head(result) do
      min(count, opts.limit)
    else
      error ->
        _ =
          Logger.warn("Can't retrieve count for #{inspect(count_query)}: #{inspect(error)}.",
            tag: "db_error"
          )

        nil
    end
  end

  def all_properties_for_endpoint!(client, device_id, interface_row, endpoint_row, endpoint_id) do
    query_statement =
      prepare_get_property_statement(
        ValueType.from_int(endpoint_row[:value_type]),
        false,
        interface_row[:storage],
        StorageType.from_int(interface_row[:storage_type])
      )

    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(query_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_row[:interface_id])
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)

    DatabaseQuery.call!(client, query)
  end

  def retrieve_datastream_values(
        client,
        device_id,
        interface_row,
        endpoint_row,
        endpoint_id,
        path,
        opts
      ) do
    {values_query_statement, count_query_statement, q_params} =
      prepare_get_individual_datastream_statement(
        ValueType.from_int(endpoint_row[:value_type]),
        false,
        interface_row[:storage],
        StorageType.from_int(interface_row[:storage_type]),
        opts
      )

    values_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(values_query_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_row[:interface_id])
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.merge(q_params)

    values = DatabaseQuery.call!(client, values_query)

    count_query =
      values_query
      |> DatabaseQuery.statement(count_query_statement)

    count = get_results_count(client, count_query, opts)

    {:ok, count, values}
  end

  def prepare_value_type_query(interface_id) do
    value_type_statement = """
    SELECT value_type
    FROM endpoints
    WHERE interface_id=:interface_id AND endpoint_id=:endpoint_id
    """

    DatabaseQuery.new()
    |> DatabaseQuery.statement(value_type_statement)
    |> DatabaseQuery.put(:interface_id, interface_id)
  end

  def execute_value_type_query(client, value_type_query, endpoint_id) do
    value_type_query =
      value_type_query
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)

    DatabaseQuery.call!(client, value_type_query)
    |> DatabaseResult.head()
  end
end
