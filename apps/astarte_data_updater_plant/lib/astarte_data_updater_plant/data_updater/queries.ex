#
# This file is part of Astarte.
#
# Copyright 2018 - 2023 SECO Mind Srl
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
  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataUpdaterPlant.DataUpdater.SimpleTrigger
  alias Astarte.DataUpdaterPlant.DataUpdater.Device
  alias Astarte.DataUpdaterPlant.DataUpdater.Endpoint
  alias Astarte.DataUpdaterPlant.DataUpdater.IndividualProperty
  alias Astarte.DataUpdaterPlant.DataUpdater.KvStore
  alias Astarte.DataUpdaterPlant.DataUpdater.Realm
  alias CQEx.Query, as: DatabaseQuery
  alias Astarte.DataUpdaterPlant.Repo
  import Ecto.Query
  require Logger

  def query_simple_triggers!(realm, object_id, object_type_int) do
    keyspace_name = Realm.keyspace_name(realm)

    query =
      SimpleTrigger
      |> where(object_id: ^object_id, object_type: ^object_type_int)
      |> put_query_prefix(keyspace_name)

    Repo.all(query)
  end

  def all_device_owned_property_endpoint_paths!(
        realm,
        device_id,
        interface_descriptor,
        endpoint_id
      ) do
    %InterfaceDescriptor{interface_id: interface_id, storage: storage} = interface_descriptor

    keyspace_name = Realm.keyspace_name(realm)

    q =
      from(storage)
      |> select([s], s.path)
      |> where(device_id: ^device_id, interface_id: ^interface_id, endpoint_id: ^endpoint_id)
      |> put_query_prefix(keyspace_name)

    Repo.all(q)
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
        Logger.warning("Database error: #{error_message}.")
        {:error, :database_error}

      {:error, reason} ->
        # DB Error
        Logger.warning("Failed with reason #{inspect(reason)}.")
        {:error, :database_error}
    end
  end

  def insert_value_into_db(
        db_client,
        _realm,
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
      Logger.warning("Tried to unset value on allow_unset=false mapping.")
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
        _realm,
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
        _realm,
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
        realm,
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

    keyspace_name = Realm.keyspace_name(realm)

    %InterfaceDescriptor{interface_id: interface_id} = interface_descriptor

    # TODO: we should cache endpoints by interface_id
    endpoint_rows =
      Endpoint
      |> select([:endpoint, :value_type])
      |> where(interface_id: ^interface_id)
      |> put_query_prefix(keyspace_name)
      |> Repo.all()

    # TODO: we should also cache explicit_timestamp
    explicit_timestamp_query =
      from e in Endpoint,
        prefix: ^keyspace_name,
        where: e.interface_id == ^interface_id,
        select: e.explicit_timestamp,
        limit: 1

    [explicit_timestamp?] = Repo.all(explicit_timestamp_query)

    # FIXME: new atoms are created here, we should avoid this. We need to replace CQEx.
    column_atoms =
      Enum.reduce(endpoint_rows, %{}, fn endpoint, column_atoms_acc ->
        endpoint_name =
          endpoint.endpoint
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
          Logger.warning(
            "Unexpected object key #{inspect(obj_key)} with value #{inspect(obj_value)}."
          )

          query_values_acc
        end
      end)

    {query_columns, placeholders} =
      if explicit_timestamp? do
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
        Logger.warning("Error while upserting path: #{path} (reason: #{inspect(reason)}).")
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

  def retrieve_device_stats_and_introspection!(realm, device_id) do
    keyspace_name = Realm.keyspace_name(realm)

    stats =
      Device
      |> where(device_id: ^device_id)
      |> select([
        :total_received_msgs,
        :total_received_bytes,
        :introspection,
        :exchanged_bytes_by_interface,
        :exchanged_msgs_by_interface
      ])
      |> put_query_prefix(keyspace_name)
      |> Repo.one(consistency: :local_quorum)

    %{
      introspection: stats.introspection,
      total_received_msgs: stats.total_received_msgs,
      total_received_bytes: stats.total_received_bytes,
      initial_interface_exchanged_bytes: stats.exchanged_bytes_by_interface,
      initial_interface_exchanged_msgs: stats.exchanged_msgs_by_interface
    }
  end

  def set_device_connected!(db_client, device_id, timestamp_ms, ip_address) do
    set_connection_info!(db_client, device_id, timestamp_ms, ip_address)

    ttl = heartbeat_interval_seconds() * 8
    refresh_device_connected!(db_client, device_id, ttl)
  end

  def maybe_refresh_device_connected!(db_client, realm, device_id) do
    with {:ok, remaining_ttl} <- get_connected_remaining_ttl(realm, device_id) do
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

  defp get_connected_remaining_ttl(realm, device_id) do
    keyspace_name = Realm.keyspace_name(realm)

    query =
      Device
      |> where(device_id: ^device_id)
      |> select([device], fragment("TTL(?)", device.connected))
      |> put_query_prefix(keyspace_name)

    case Repo.fetch_one(query, consistency: :quorum) do
      n when is_number(n) ->
        {:ok, n}

      nil ->
        {:error, :device_not_found}

      {:error, reason} ->
        _ =
          Logger.warning(
            "Could not get remaining connection ttl for #{CoreDevice.encode_device_id(device_id)}",
            realm: "realm",
            tag: "get_connected_remaining_ttl_fail"
          )

        {:error, reason}
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

  def fetch_device_introspection_minors(realm, device_id) do
    keyspace_name = Realm.keyspace_name(realm)

    query =
      Device
      |> select([d], d.introspection_minor)
      |> where(device_id: ^device_id)
      |> put_query_prefix(keyspace_name)

    with minors when is_map(minors) <- Repo.fetch_one(query, consistency: :quorum) do
      {:ok, minors}
    end
  end

  def get_device_groups(realm, device_id) do
    keyspace_name = Realm.keyspace_name(realm)

    query =
      Device
      |> select([d], d.groups)
      |> where(device_id: ^device_id)
      |> put_query_prefix(keyspace_name)

    with groups when is_map(groups) <- Repo.fetch_one(query, consistency: :quorum) do
      {:ok, Map.keys(groups)}
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
    encoded_device_id = CoreDevice.encode_device_id(device_id)

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
        Logger.warning(
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
    encoded_device_id = CoreDevice.encode_device_id(device_id)

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
        Logger.warning(
          "Database error: cannot unregister device-interface pair: #{inspect(reason)}."
        )

        {:error, reason}
    end
  end

  def check_device_exists(realm, device_id) do
    keyspace_name = Realm.keyspace_name(realm)

    query =
      Device
      |> select([d], d.device_id)
      |> where(device_id: ^device_id)
      |> put_query_prefix(keyspace_name)

    case Repo.fetch_one(query) do
      device_id when is_binary(device_id) -> {:ok, true}
      nil -> {:ok, false}
      {:error, reason} -> {:error, reason}
    end
  end

  defp to_db_friendly_type(array) when is_list(array) do
    # If we have an array, we convert its elements to a db friendly type
    Enum.map(array, &to_db_friendly_type/1)
  end

  defp to_db_friendly_type(%DateTime{} = datetime) do
    DateTime.to_unix(datetime, :millisecond)
  end

  # From Cyanide 2.0, binaries are decoded as %Cyanide.Binary{}
  defp to_db_friendly_type(%Cyanide.Binary{subtype: _subtype, data: bin}) do
    bin
  end

  defp to_db_friendly_type(value) do
    value
  end

  def retrieve_property_values(realm, device_id, interface_descriptor, mapping) do
    %InterfaceDescriptor{
      storage_type: :multi_interface_individual_properties_dbtable,
      interface_id: interface_id,
      storage: storage
    } = interface_descriptor

    %Mapping{endpoint_id: endpoint_id, value_type: value_type} = mapping

    column_name = CQLUtils.mapping_value_type_to_db_type(value_type) |> String.to_existing_atom()
    keyspace_name = Realm.keyspace_name(realm)

    from(storage)
    |> select(^[:path, column_name])
    |> where(device_id: ^device_id, interface_id: ^interface_id, endpoint_id: ^endpoint_id)
    |> put_query_prefix(keyspace_name)
    |> Repo.all()
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

  def fetch_datastream_maximum_storage_retention(realm) do
    keyspace_name = Realm.keyspace_name(realm)

    query =
      KvStore
      |> where(group: "realm_config", key: "datastream_maximum_storage_retention")
      |> select([v], fragment("blobAsInt(?)", v.value))
      |> put_query_prefix(keyspace_name)

    with n when is_number(n) or is_nil(n) <- Repo.fetch_one(query, consistency: :quorum) do
      {:ok, n}
    end
  end

  def fetch_path_expiry(realm, device_id, interface_descriptor, %Mapping{} = mapping, path)
      when is_binary(device_id) and is_binary(path) do
    %InterfaceDescriptor{interface_id: interface_id} = interface_descriptor
    %Mapping{endpoint_id: endpoint_id} = mapping

    keyspace_name = Realm.keyspace_name(realm)

    q =
      IndividualProperty
      |> where(
        device_id: ^device_id,
        interface_id: ^interface_id,
        endpoint_id: ^endpoint_id,
        path: ^path
      )
      |> put_query_prefix(keyspace_name)
      |> select([p], fragment("TTL(?)", p.reception_timestamp))

    case Repo.fetch_all(q, consistency: :quorum) do
      [] ->
        {:error, :property_not_set}

      [nil] ->
        {:ok, :no_expiry}

      [ttl] when is_integer(ttl) ->
        expiry_datetime =
          DateTime.utc_now()
          |> DateTime.to_unix()
          |> :erlang.+(ttl)
          |> DateTime.from_unix!()

        {:ok, expiry_datetime}

      {:error, reason} ->
        %InterfaceDescriptor{name: name, major_version: major, minor_version: minor} =
          interface_descriptor

        _ =
          Logger.warning(
            "Could not fetch path #{path} expiry for #{name} v#{major}.#{minor}: #{inspect(reason)}",
            realm: realm,
            tag: "fetch_path_expiry_fail"
          )

        {:error, reason}
    end
  end

  def ack_end_device_deletion(realm_name, device_id) do
    Xandra.Cluster.run(
      :xandra,
      &do_ack_end_device_deletion(&1, realm_name, device_id)
    )
  end

  defp do_ack_end_device_deletion(conn, realm_name, device_id) do
    statement = """
    UPDATE #{realm_name}.deletion_in_progress
    SET dup_end_ack = true
    WHERE device_id = :device_id
    """

    with {:ok, prepared} <- Xandra.prepare(conn, statement),
         {:ok, %Xandra.Void{}} <-
           Xandra.execute(conn, prepared, %{"device_id" => device_id}, uuid_format: :binary) do
      :ok
    else
      {:error, %Xandra.Error{} = error} ->
        _ =
          Logger.warning(
            "Database error while writing device deletion end ack: #{Exception.message(error)}"
          )

        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = error} ->
        _ =
          Logger.warning(
            "Database connection error while writing device deletion end ack: #{Exception.message(error)}"
          )

        {:error, :database_connection_error}
    end
  end

  def ack_start_device_deletion(realm_name, device_id) do
    Xandra.Cluster.run(
      :xandra,
      &do_ack_start_device_deletion(&1, realm_name, device_id)
    )
  end

  defp do_ack_start_device_deletion(conn, realm_name, device_id) do
    statement = """
    UPDATE #{realm_name}.deletion_in_progress
    SET dup_start_ack = true
    WHERE device_id = :device_id
    """

    with {:ok, prepared} <- Xandra.prepare(conn, statement),
         {:ok, %Xandra.Void{}} <-
           Xandra.execute(conn, prepared, %{"device_id" => device_id}, uuid_format: :binary) do
      :ok
    else
      {:error, %Xandra.Error{} = error} ->
        _ =
          Logger.warning(
            "Database error while writing device deletion start ack: #{Exception.message(error)}"
          )

        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = error} ->
        _ =
          Logger.warning(
            "Database connection error while writing device deletion start ack: #{Exception.message(error)}"
          )

        {:error, :database_connection_error}
    end
  end

  def check_device_deletion_in_progress(realm_name, device_id) do
    Xandra.Cluster.run(
      :xandra,
      &do_check_device_deletion_in_progress(&1, realm_name, device_id)
    )
  end

  defp do_check_device_deletion_in_progress(conn, realm_name, device_id) do
    statement = """
    SELECT *
    FROM #{realm_name}.deletion_in_progress
    WHERE device_id = :device_id
    """

    with {:ok, prepared} <- Xandra.prepare(conn, statement),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, prepared, %{"device_id" => device_id}, uuid_format: :binary) do
      result_not_empty? = not Enum.empty?(page)
      {:ok, result_not_empty?}
    else
      {:error, %Xandra.Error{} = error} ->
        _ =
          Logger.warning(
            "Database error while checking device deletion in progress: #{Exception.message(error)}"
          )

        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = error} ->
        _ =
          Logger.warning(
            "Database connection error while checking device deletion in progress: #{Exception.message(error)}"
          )

        {:error, :database_connection_error}
    end
  end

  def retrieve_realms! do
    statement = """
    SELECT *
    FROM #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms
    """

    realms =
      Xandra.Cluster.run(
        :xandra,
        &Xandra.execute!(&1, statement, %{}, consistency: :local_quorum)
      )

    Enum.to_list(realms)
  end

  def retrieve_devices_waiting_to_start_deletion!(realm_name) do
    Xandra.Cluster.run(
      :xandra,
      &do_retrieve_devices_waiting_to_start_deletion!(&1, realm_name)
    )
  end

  defp do_retrieve_devices_waiting_to_start_deletion!(conn, realm_name) do
    statement = """
    SELECT *
    FROM #{realm_name}.deletion_in_progress
    """

    Xandra.execute!(conn, statement, %{},
      consistency: :local_quorum,
      uuid_format: :binary
    )
    |> Enum.to_list()
  end
end
