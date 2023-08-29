#
# This file is part of Astarte.
#
# Copyright 2018-2023 SECO Mind Srl
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
  require Logger

  @default_query_opts [uuid_format: :binary, timestamp_format: :integer]
  @default_custom_query_opts [result: :default, context: nil]

  def query_simple_triggers!(realm_name, object_id, object_type_int) do
    simple_triggers_statement = """
    SELECT simple_trigger_id, parent_trigger_id, trigger_data, trigger_target
    FROM simple_triggers
    WHERE object_id=:object_id AND object_type=:object_type_int
    """

    params = %{
      "object_id" => object_id,
      "object_type_int" => object_type_int
    }

    custom_query!(simple_triggers_statement, realm_name, params)
  end

  def query_all_endpoint_paths!(realm_name, device_id, interface_descriptor, endpoint_id) do
    all_paths_statement = """
    SELECT path FROM #{interface_descriptor.storage}
    WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id
    """

    params = %{
      "device_id" => device_id,
      "interface_id" => interface_descriptor.interface_id,
      "endpoint_id" => endpoint_id
    }

    custom_query!(all_paths_statement, realm_name, params)
  end

  def set_pending_empty_cache(realm_name, device_id, pending_empty_cache) do
    pending_empty_cache_statement = """
    UPDATE devices
    SET pending_empty_cache = :pending_empty_cache
    WHERE device_id = :device_id
    """

    params = %{
      "device_id" => device_id,
      "pending_empty_cache" => pending_empty_cache
    }

    with {:ok, _result} <- custom_query(pending_empty_cache_statement, realm_name, params) do
      :ok
    end
  end

  def insert_value_into_db(
        realm_name,
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

    statement = """
    DELETE FROM #{interface_descriptor.storage}
    WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path
    """

    # TODO: :reception_timestamp_submillis is just a place holder right now
    params = %{
      "device_id" => device_id,
      "interface_id" => interface_descriptor.interface_id,
      "endpoint_id" => endpoint.endpoint_id,
      "path" => path
    }

    consistency = insert_consistency(interface_descriptor, endpoint)

    custom_query!(statement, realm_name, params, consistency: consistency)

    :ok
  end

  def insert_value_into_db(
        realm_name,
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
    statement = """
    INSERT INTO #{interface_descriptor.storage}
    (device_id, interface_id, endpoint_id, path, reception_timestamp, #{CQLUtils.type_to_db_column_name(endpoint.value_type)})
    VALUES (:device_id, :interface_id, :endpoint_id, :path, :reception_timestamp, :value);
    """

    params = %{
      "device_id" => device_id,
      "interface_id" => interface_descriptor.interface_id,
      "endpoint_id" => endpoint.endpoint_id,
      "path" => path,
      "reception_timestamp" => div(reception_timestamp, 10000),
      "reception_timestamp_submillis" => rem(reception_timestamp, 10000),
      "value" => to_db_friendly_type(value)
    }

    consistency = insert_consistency(interface_descriptor, endpoint)

    custom_query!(statement, realm_name, params, consistency: consistency)

    :ok
  end

  def insert_value_into_db(
        realm_name,
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

    statement = """
    INSERT INTO #{interface_descriptor.storage}
    (device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, #{CQLUtils.type_to_db_column_name(endpoint.value_type)})
    VALUES (:device_id, :interface_id, :endpoint_id, :path, :value_timestamp, :reception_timestamp, :reception_timestamp_submillis, :value) #{ttl_string};
    """

    # TODO: use received value_timestamp when needed
    # TODO: :reception_timestamp_submillis is just a place holder right now
    params = %{
      "device_id" => device_id,
      "interface_id" => interface_descriptor.interface_id,
      "endpoint_id" => endpoint.endpoint_id,
      "path" => path,
      "value_timestamp" => value_timestamp,
      "reception_timestamp" => div(reception_timestamp, 10000),
      "reception_timestamp_submillis" => rem(reception_timestamp, 10000),
      "value" => to_db_friendly_type(value)
    }

    consistency = insert_consistency(interface_descriptor, endpoint)

    custom_query!(statement, realm_name, params, consistency: consistency)

    :ok
  end

  def insert_value_into_db(
        realm_name,
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
    endpoint_statement =
      "SELECT endpoint, value_type FROM endpoints WHERE interface_id=:interface_id;"

    endpoint_params = %{
      "interface_id" => interface_descriptor.interface_id
    }

    endpoint_rows = custom_query!(endpoint_statement, realm_name, endpoint_params)

    # TODO: we should also cache explicit_timestamp
    explicit_timestamp_statement =
      "SELECT explicit_timestamp FROM endpoints WHERE interface_id=:interface_id LIMIT 1;"

    explicit_timestamp_params = %{"interface_id" => interface_descriptor.interface_id}

    %{"explicit_timestamp" => explicit_timestamp} =
      custom_query!(explicit_timestamp_statement, realm_name, explicit_timestamp_params,
        result: :first!
      )

    endpoints =
      Enum.map(endpoint_rows, fn %{"endpoint" => endpoint_name} ->
        endpoint_name
        |> String.split("/")
        |> List.last()
      end)

    {endpoints, invalid} = Enum.split_with(value, fn {key, _} -> key in endpoints end)

    for {key, val} <- invalid do
      Logger.warn("Unexpected object key #{inspect(key)} with value #{inspect(val)}.")
    end

    query_values =
      for {key, value} <- endpoints, into: %{} do
        column = CQLUtils.endpoint_to_db_column_name(key)
        value = to_db_friendly_type(value)
        {column, value}
      end

    db_columns = Map.keys(query_values)

    placeholders =
      db_columns
      |> Enum.map_join(" ", &":#{&1},")

    query_columns =
      db_columns
      |> Enum.map_join(" ", &"#{&1},")

    {query_columns, placeholders} =
      if explicit_timestamp do
        {"value_timestamp, #{query_columns}", ":value_timestamp, #{placeholders}"}
      else
        {query_columns, placeholders}
      end

    statement = """
    INSERT INTO #{interface_descriptor.storage} (device_id, path, #{query_columns} reception_timestamp, reception_timestamp_submillis)
    VALUES (:device_id, :path, #{placeholders} :reception_timestamp, :reception_timestamp_submillis) #{ttl_string};
    """

    # TODO: use received value_timestamp when needed
    # TODO: :reception_timestamp_submillis is just a place holder right now
    params =
      %{
        "device_id" => device_id,
        "path" => path,
        "value_timestamp" => value_timestamp,
        "reception_timestamp" => div(reception_timestamp, 10000),
        "reception_timestamp_submillis" => rem(reception_timestamp, 10000)
      }
      |> Map.merge(query_values)

    # TODO: consistency = insert_consistency(interface_descriptor, endpoint)

    custom_query!(statement, realm_name, params)

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
        realm_name,
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
      realm_name,
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
        realm_name,
        device_id,
        %InterfaceDescriptor{storage_type: :one_object_datastream_dbtable} = interface_descriptor,
        mapping,
        path,
        value_timestamp,
        reception_timestamp,
        opts
      ) do
    insert_path(
      realm_name,
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
         realm_name,
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

    params = %{
      "device_id" => device_id,
      "interface_id" => interface_descriptor.interface_id,
      "endpoint_id" => endpoint.endpoint_id,
      "path" => path,
      "reception_timestamp" => div(reception_timestamp, 10000),
      "reception_timestamp_submillis" => rem(reception_timestamp, 10000),
      "datetime_value" => value_timestamp
    }

    consistency = path_consistency(interface_descriptor, endpoint)

    with {:ok, _result} <-
           custom_query(insert_statement, realm_name, params,
             consistency: consistency,
             context: "upserting path: #{path}"
           ) do
      :ok
    end
  end

  def delete_property_from_db(state, interface_descriptor, endpoint_id, path) do
    statement =
      "DELETE FROM #{interface_descriptor.storage} WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path;"

    params = %{
      "device_id" => state.device_id,
      "interface_id" => interface_descriptor.interface_id,
      "endpoint_id" => endpoint_id,
      "path" => path
    }

    # TODO: consistency = insert_consistency(interface_descriptor, endpoint)

    custom_query!(statement, state.realm, params)
    :ok
  end

  def retrieve_device_stats_and_introspection!(realm_name, device_id) do
    stats_and_introspection_statement = """
    SELECT total_received_msgs, total_received_bytes, introspection,
           exchanged_bytes_by_interface, exchanged_msgs_by_interface
    FROM devices
    WHERE device_id=:device_id
    """

    params = %{"device_id" => device_id}

    device_row =
      custom_query!(stats_and_introspection_statement, realm_name, params,
        result: :first!,
        consistency: :local_quorum
      )

    %{
      introspection: device_row["introspection"] || %{},
      total_received_msgs: device_row["total_received_msgs"],
      total_received_bytes: device_row["total_received_bytes"],
      initial_interface_exchanged_bytes: device_row["exchanged_bytes_by_interface"] || %{},
      initial_interface_exchanged_msgs: device_row["exchanged_msgs_by_interface"] || %{}
    }
  end

  def set_device_connected!(realm_name, device_id, timestamp_ms, ip_address) do
    set_connection_info!(realm_name, device_id, timestamp_ms, ip_address)

    ttl = heartbeat_interval_seconds() * 8
    refresh_device_connected!(realm_name, device_id, ttl)
  end

  def maybe_refresh_device_connected!(realm_name, device_id) do
    with {:ok, remaining_ttl} <- get_connected_remaining_ttl(realm_name, device_id) do
      if remaining_ttl < heartbeat_interval_seconds() * 2 do
        Logger.debug("Refreshing connected status", tag: "refresh_device_connected")
        write_ttl = heartbeat_interval_seconds() * 8
        refresh_device_connected!(realm_name, device_id, write_ttl)
      else
        :ok
      end
    end
  end

  defp heartbeat_interval_seconds do
    Config.device_heartbeat_interval_ms!() |> div(1000)
  end

  defp set_connection_info!(realm_name, device_id, timestamp_ms, ip_address) do
    device_update_statement = """
    UPDATE devices
    SET last_connection=:last_connection, last_seen_ip=:last_seen_ip
    WHERE device_id=:device_id
    """

    params = %{
      "device_id" => device_id,
      "last_connection" => timestamp_ms,
      "last_seen_ip" => ip_address
    }

    custom_query!(device_update_statement, realm_name, params, consistency: :local_quorum)
  end

  defp refresh_device_connected!(realm_name, device_id, ttl) do
    refresh_connected_statement = """
    UPDATE devices
    USING TTL #{ttl}
    SET connected=true
    WHERE device_id=:device_id
    """

    params = %{"device_id" => device_id}

    custom_query!(refresh_connected_statement, realm_name, params, consistency: :local_quorum)
  end

  defp get_connected_remaining_ttl(realm_name, device_id) do
    fetch_connected_ttl_statement = """
    SELECT TTL(connected)
    FROM devices
    WHERE device_id=:device_id
    """

    params = %{"device_id" => device_id}

    with {:ok, result} <-
           custom_query(fetch_connected_ttl_statement, realm_name, params,
             consistency: :quorum,
             result: {:first!, :device_not_found},
             context: "retrieving property"
           ) do
      %{"ttl(connected)" => ttl} = result
      ttl = ttl || 0
      {:ok, ttl}
    end
  end

  def set_device_disconnected!(
        realm_name,
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

    params = %{
      "device_id" => device_id,
      "last_disconnection" => timestamp_ms,
      "total_received_msgs" => total_received_msgs,
      "total_received_bytes" => total_received_bytes,
      "exchanged_bytes_by_interface" => interface_exchanged_bytes,
      "exchanged_msgs_by_interface" => interface_exchanged_msgs
    }

    custom_query!(device_update_statement, realm_name, params, consistency: :local_quorum)
  end

  def fetch_device_introspection_minors(realm_name, device_id) do
    introspection_minor_statement = """
    SELECT introspection_minor
    FROM devices
    WHERE device_id=:device_id
    """

    params = %{"device_id" => device_id}

    with {:ok, result} <-
           custom_query(introspection_minor_statement, realm_name, params,
             consistency: :quorum,
             result: :first!
           ) do
      %{"introspection_minor" => introspection_minors} = result
      introspection_minors = introspection_minors || %{}
      {:ok, introspection_minors}
    end
  end

  def get_device_groups(realm_name, device_id) do
    groups_statement = """
    SELECT groups
    FROM devices
    WHERE device_id=:device_id
    """

    params = %{"device_id" => device_id}

    with {:ok, result} <-
           custom_query(groups_statement, realm_name, params,
             consistency: :quorum,
             result: :first!
           ) do
      %{"groups" => groups} = result
      groups = groups || %{}
      {:ok, Map.keys(groups)}
    end
  end

  def update_device_introspection!(realm_name, device_id, introspection, introspection_minor) do
    introspection_update_statement = """
    UPDATE devices
    SET introspection=:introspection, introspection_minor=:introspection_minor
    WHERE device_id=:device_id
    """

    params = %{
      "device_id" => device_id,
      "introspection" => introspection,
      "introspection_minor" => introspection_minor
    }

    custom_query!(introspection_update_statement, realm_name, params, consistency: :quorum)
  end

  def add_old_interfaces(realm_name, device_id, old_interfaces) do
    old_introspection_update_statement = """
    UPDATE devices
    SET old_introspection = old_introspection + :introspection
    WHERE device_id=:device_id
    """

    params = %{"device_id" => device_id, "introspection" => old_interfaces}

    with {:ok, _result} <-
           custom_query(old_introspection_update_statement, realm_name, params,
             consistency: :quorum
           ) do
      :ok
    end
  end

  def remove_old_interfaces(realm_name, device_id, old_interfaces) do
    old_introspection_remove_statement = """
    UPDATE devices
    SET old_introspection = old_introspection - :old_interfaces
    WHERE device_id=:device_id
    """

    params = %{"device_id" => device_id, "old_interfaces" => old_interfaces}

    with {:ok, _result} <-
           custom_query(old_introspection_remove_statement, realm_name, params,
             consistency: :quorum
           ) do
      :ok
    end
  end

  def register_device_with_interface(realm_name, device_id, interface_name, interface_major) do
    key_insert_statement = """
    INSERT INTO kv_store (group, key)
    VALUES (:group, :key)
    """

    major_str = "v#{Integer.to_string(interface_major)}"
    encoded_device_id = Device.encode_device_id(device_id)

    devices_by_interface_params = %{
      "group" => "devices-by-interface-#{interface_name}-#{major_str}",
      "key" => encoded_device_id
    }

    data_on_interface_params = %{
      "group" => "devices-with-data-on-interface-#{interface_name}-#{major_str}",
      "key" => encoded_device_id
    }

    with {:ok, _result} <-
           custom_query(key_insert_statement, realm_name, devices_by_interface_params,
             consistency: :each_quorum,
             context: "registering device-interface pair"
           ),
         {:ok, _result} <-
           custom_query(key_insert_statement, realm_name, data_on_interface_params,
             consistency: :each_quorum,
             context: "registering device-interface pair"
           ) do
      :ok
    end
  end

  def unregister_device_with_interface(realm_name, device_id, interface_name, interface_major) do
    key_delete_statement = """
    DELETE FROM kv_store
    WHERE group=:group AND key=:key
    """

    major_str = "v#{Integer.to_string(interface_major)}"
    encoded_device_id = Device.encode_device_id(device_id)

    params = %{
      "group" => "devices-by-interface-#{interface_name}-#{major_str}",
      "key" => encoded_device_id
    }

    with {:ok, _result} <-
           custom_query(key_delete_statement, realm_name, params,
             consistency: :each_quorum,
             context: "unregistering device-interface pair"
           ) do
      :ok
    end
  end

  def check_device_exists(realm_name, device_id) do
    device_statement = """
    SELECT device_id
    FROM devices
    WHERE device_id=:device_id
    """

    params = %{"device_id" => device_id}

    with {:ok, _result} <-
           custom_query(device_statement, realm_name, params,
             result: {:first!, :device_does_not_exist}
           ) do
      :ok
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

  def retrieve_endpoint_values(realm_name, device_id, interface_descriptor, mapping) do
    query_statement =
      prepare_get_property_statement(
        mapping.value_type,
        false,
        interface_descriptor.storage,
        interface_descriptor.storage_type
      )

    params = %{
      "device_id" => device_id,
      "interface_id" => interface_descriptor.interface_id,
      "endpoint_id" => mapping.endpoint_id
    }

    {:ok, result} = custom_query(query_statement, realm_name, params)
    result
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

  def fetch_datastream_maximum_storage_retention(realm_name) do
    maximum_storage_retention_statement = """
    SELECT blobAsInt(value)
    FROM kv_store
    WHERE group='realm_config' AND key='datastream_maximum_storage_retention'
    """

    with {:ok, result} <-
           custom_query(maximum_storage_retention_statement, realm_name, %{},
             result: :first,
             consistency: :quorum
           ) do
      maximum_storage_retention = result["system.blobasint(value)"]
      {:ok, maximum_storage_retention}
    end
  end

  def fetch_path_expiry(realm_name, device_id, interface_descriptor, %Mapping{} = mapping, path)
      when is_binary(device_id) and is_binary(path) do
    # TODO: do not hardcode individual_properties here
    fetch_property_value_statement = """
    SELECT TTL(datetime_value)
    FROM individual_properties
    WHERE device_id=:device_id AND interface_id=:interface_id
      AND endpoint_id=:endpoint_id AND path=:path
    """

    params = %{
      "device_id" => device_id,
      "interface_id" => interface_descriptor.interface_id,
      "endpoint_id" => mapping.endpoint_id,
      "path" => path
    }

    with {:ok, result} <-
           custom_query(fetch_property_value_statement, realm_name, params,
             consistency: :quorum,
             result: {:first!, :property_not_set}
           ) do
      %{"ttl(datetime_value)" => ttl} = result

      if ttl == nil do
        {:ok, :no_expiry}
      else
        expiry_datetime =
          DateTime.utc_now()
          |> DateTime.to_unix()
          |> :erlang.+(ttl)
          |> DateTime.from_unix!()

        {:ok, expiry_datetime}
      end
    end
  end

  # TODO: add to astarte_data_access
  def custom_query(statement, realm \\ nil, params \\ %{}, opts \\ []) do
    do_custom_query(&execute_query/6, statement, realm, params, opts)
  end

  def custom_query!(statement, realm \\ nil, params \\ %{}, opts \\ []) do
    do_custom_query(&execute_query!/6, statement, realm, params, opts)
  end

  defp do_custom_query(execute_query, statement, realm, params, opts) do
    {custom_opts, query_opts} = parse_opts(opts)
    cluster = Config.xandra_options!()[:name]

    Xandra.Cluster.run(
      cluster,
      &execute_query.(&1, statement, realm, params, query_opts, custom_opts)
    )
  end

  defp execute_query(conn, statement, realm, params, query_opts, custom_opts) do
    with {:ok, prepared} <- prepare_query(conn, statement, realm) do
      case Xandra.execute(conn, prepared, params, query_opts) do
        {:ok, result} ->
          cast_query_result(result, custom_opts)

        {:error, error} ->
          %{message: message, tag: tag} = database_error_message(error, custom_opts[:context])

          _ = Logger.warn(message, tag: tag)

          {:error, :database_error}
      end
    end
  end

  defp execute_query!(conn, statement, realm, params, query_opts, custom_opts) do
    prepared = prepare_query!(conn, statement, realm)

    Xandra.execute!(conn, prepared, params, query_opts)
    |> cast_query_result!(custom_opts)
  end

  defp use_realm(_conn, nil = _realm), do: :ok

  defp use_realm(conn, realm) when is_binary(realm) do
    with true <- Astarte.Core.Realm.valid_name?(realm),
         {:ok, %Xandra.SetKeyspace{}} <- Xandra.execute(conn, "USE #{realm}") do
      :ok
    else
      _ -> {:error, :realm_not_found}
    end
  end

  defp prepare_query(conn, statement, realm) do
    with :ok <- use_realm(conn, realm) do
      case Xandra.prepare(conn, statement) do
        {:ok, page} ->
          {:ok, page}

        {:error, reason} ->
          _ = Logger.warn("Cannot prepare query: #{inspect(reason)}.", tag: "db_error")
          {:error, :database_error}
      end
    end
  end

  defp prepare_query!(conn, statement, realm) do
    :ok = use_realm(conn, realm)
    Xandra.prepare!(conn, statement)
  end

  defp parse_opts(opts) do
    {custom_opts, query_opts} = Keyword.split(opts, Keyword.keys(@default_custom_query_opts))
    query_opts = Keyword.merge(@default_query_opts, query_opts)
    custom_opts = Keyword.validate!(custom_opts, @default_custom_query_opts)

    {custom_opts, query_opts}
  end

  defp cast_query_result(result, opts) do
    result_with_defaults =
      case opts[:result] do
        :first -> {:first, nil}
        :first! -> {:first!, :not_found}
        x -> x
      end

    case result_with_defaults do
      :default ->
        {:ok, result}

      :list ->
        {:ok, Enum.to_list(result)}

      {:first, default} ->
        {:ok, Enum.at(result, 0, default)}

      {:first!, error} ->
        Enum.fetch(result, 0)
        |> case do
          :error -> {:error, error}
          {:ok, first} -> {:ok, first}
        end
    end
  end

  defp cast_query_result!(result, opts) do
    case opts[:result] do
      :default ->
        result

      :list ->
        Enum.to_list(result)

      :first ->
        Enum.at(result, 0)

      {:first, default} ->
        Enum.at(result, 0, default)

      :first! ->
        Enum.fetch!(result, 0)
    end
  end

  defp database_error_message(%Xandra.Error{message: message, reason: reason}, nil = _context) do
    %{message: "Database error #{reason}: #{message}", tag: "db_error"}
  end

  defp database_error_message(%Xandra.Error{message: message, reason: reason}, context) do
    %{message: "Database error #{reason} during #{context}: #{message}", tag: "db_error"}
  end

  defp database_error_message(
         %Xandra.ConnectionError{action: action, reason: reason},
         nil = _context
       ) do
    %{message: "Database connection error: #{reason} (#{action})", tag: "db_connection_error"}
  end

  defp database_error_message(%Xandra.ConnectionError{action: action, reason: reason}, context) do
    %{
      message: "Database connection error during #{context}: #{reason} (#{action})",
      tag: "db_connection_error"
    }
  end
end
