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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Queries do
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataAccess.Realms.SimpleTrigger
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Realms.IndividualProperty
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataUpdaterPlant.Repo
  import Ecto.Query
  require Logger

  def query_simple_triggers!(realm, object_id, object_type_int) do
    keyspace_name = Realm.keyspace_name(realm)

    query =
      SimpleTrigger
      |> where(object_id: ^object_id, object_type: ^object_type_int)
      |> put_query_prefix(keyspace_name)

    Repo.all(query, consistency: Consistency.domain_model(:read))
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

    Repo.all(q, consistency: Consistency.device_info(:read))
  end

  def set_pending_empty_cache(realm, device_id, pending_empty_cache) do
    keyspace_name = Realm.keyspace_name(realm)

    device =
      from d in Device,
        prefix: ^keyspace_name,
        where: [device_id: ^device_id],
        update: [set: [pending_empty_cache: ^pending_empty_cache]]

    case Repo.safe_update_all(device, [], consistency: Consistency.device_info(:write)) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        _ =
          Logger.warning(
            "Cannot set pending empty cache for device #{CoreDevice.encode_device_id(device_id)}: #{inspect(reason)}",
            realm: realm,
            tag: "set_pending_empty_cache_fail"
          )

        {:error, reason}
    end
  end

  def insert_value_into_db(
        realm,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_properties_dbtable} =
          interface_descriptor,
        %Mapping{allow_unset: true} = mapping,
        path,
        nil,
        _value_timestamp,
        _reception_timestamp,
        opts
      ) do
    %InterfaceDescriptor{storage: storage, interface_id: interface_id} = interface_descriptor
    %Mapping{endpoint_id: endpoint_id} = mapping
    keyspace = Realm.keyspace_name(realm)

    _ =
      remove_property_row(keyspace, storage, device_id, interface_id, endpoint_id, path, opts)

    :ok
  end

  def insert_value_into_db(
        realm,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_properties_dbtable} =
          _interface_descriptor,
        _mapping,
        _path,
        nil,
        _value_timestamp,
        _reception_timestamp,
        _opts
      ) do
    _ =
      Logger.warning(
        "Device #{inspect(device_id)} in realm #{realm} tried to unset an unsettable property.",
        tag: :unset_not_allowed
      )

    {:error, :unset_not_allowed}
  end

  def insert_value_into_db(
        realm,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_properties_dbtable} =
          interface_descriptor,
        mapping,
        path,
        value,
        _value_timestamp,
        reception_timestamp,
        _opts
      ) do
    %InterfaceDescriptor{interface_id: interface_id, storage: storage} = interface_descriptor
    %Mapping{endpoint_id: endpoint_id, value_type: value_type} = mapping
    keyspace_name = Realm.keyspace_name(realm)
    timestamp = div(reception_timestamp, 10000)
    reception_timestamp_submillis = rem(reception_timestamp, 10000)
    column_name = CQLUtils.type_to_db_column_name(value_type)
    db_value = to_db_friendly_type(value)

    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_value = %{
      "device_id" => device_id,
      "interface_id" => interface_id,
      "endpoint_id" => endpoint_id,
      "path" => path,
      "reception_timestamp" => timestamp,
      "reception_timestamp_submillis" => reception_timestamp_submillis,
      column_name => db_value
    }

    insert_opts = [
      prefix: keyspace_name,
      consistency: Consistency.device_info(:write)
    ]

    _ = Repo.insert_all(storage, [insert_value], insert_opts)
    :ok
  end

  def insert_value_into_db(
        realm,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_datastream_dbtable} =
          interface_descriptor,
        mapping,
        path,
        value,
        value_timestamp,
        reception_timestamp,
        opts
      ) do
    %InterfaceDescriptor{interface_id: interface_id, storage: storage} = interface_descriptor
    %Mapping{endpoint_id: endpoint_id, value_type: value_type} = mapping
    keyspace_name = Realm.keyspace_name(realm)
    timestamp = div(reception_timestamp, 10000)
    reception_timestamp_submillis = rem(reception_timestamp, 10000)
    column_name = CQLUtils.type_to_db_column_name(value_type)
    db_value = to_db_friendly_type(value)

    # TODO: use received value_timestamp when needed
    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_value = %{
      "device_id" => device_id,
      "interface_id" => interface_id,
      "endpoint_id" => endpoint_id,
      "path" => path,
      "value_timestamp" => value_timestamp,
      "reception_timestamp" => timestamp,
      "reception_timestamp_submillis" => reception_timestamp_submillis,
      column_name => db_value
    }

    insert_opts = [
      prefix: keyspace_name,
      consistency: Consistency.time_series(:write, mapping)
    ]

    _ = Repo.insert_all(storage, [insert_value], Keyword.merge(opts, insert_opts))

    :ok
  end

  def insert_value_into_db(
        realm,
        device_id,
        %InterfaceDescriptor{storage_type: :one_object_datastream_dbtable} = interface_descriptor,
        mapping,
        path,
        value,
        value_timestamp,
        reception_timestamp,
        opts
      ) do
    %InterfaceDescriptor{interface_id: interface_id, storage: storage} = interface_descriptor

    keyspace_name = Realm.keyspace_name(realm)
    timestamp = div(reception_timestamp, 10000)
    reception_timestamp_submillis = rem(reception_timestamp, 10000)

    # TODO: we should cache endpoints by interface_id
    column_info =
      Endpoint
      |> select([:endpoint, :value_type])
      |> where(interface_id: ^interface_id)
      |> put_query_prefix(keyspace_name)
      |> Repo.all(consistency: Consistency.domain_model(:read))
      |> Map.new(fn endpoint ->
        value_name = endpoint.endpoint |> String.split("/") |> List.last()
        column_name = CQLUtils.endpoint_to_db_column_name(value_name)
        {value_name, column_name}
      end)

    # TODO: we should also cache explicit_timestamp
    explicit_timestamp_query =
      from e in Endpoint,
        prefix: ^keyspace_name,
        where: e.interface_id == ^interface_id,
        select: e.explicit_timestamp,
        limit: 1

    [explicit_timestamp?] =
      Repo.all(explicit_timestamp_query, consistency: Consistency.domain_model(:read))

    # TODO: use received value_timestamp when needed
    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_params = %{
      "device_id" => device_id,
      "path" => path,
      "reception_timestamp" => timestamp,
      "reception_timestamp_submillis" => reception_timestamp_submillis
    }

    object_value = compute_db_object_entries(column_info, value)

    insert_value = Map.merge(insert_params, object_value)

    insert_value =
      if explicit_timestamp? do
        Map.put(insert_value, "value_timestamp", value_timestamp)
      else
        insert_value
      end

    insert_opts = [
      prefix: keyspace_name,
      consistency: Consistency.time_series(:write, mapping)
    ]

    _ = Repo.insert_all(storage, [insert_value], Keyword.merge(opts, insert_opts))

    :ok
  end

  defp remove_property_row(
         keyspace,
         table,
         device_id,
         interface_id,
         endpoint_id,
         path,
         opts \\ []
       ) do
    query =
      from table,
        prefix: ^keyspace,
        where: [
          device_id: ^device_id,
          interface_id: ^interface_id,
          endpoint_id: ^endpoint_id,
          path: ^path
        ]

    opts = Keyword.merge(opts, consistency: Consistency.device_info(:write))

    _ = Repo.delete_all(query, opts)
  end

  defp compute_db_object_entries(column_info, object) do
    Enum.reduce(object, %{}, fn {object_key, object_value}, acc ->
      case Map.fetch(column_info, object_key) do
        {:ok, column_name} ->
          db_value = to_db_friendly_type(object_value)
          Map.put(acc, column_name, db_value)

        :error ->
          _ =
            Logger.warning(
              "Unexpected object key #{object_key} with value #{inspect(object_value)}."
            )

          acc
      end
    end)
  end

  def insert_path_into_db(
        realm,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_datastream_dbtable} =
          interface_descriptor,
        mapping,
        path,
        value_timestamp,
        reception_timestamp,
        opts
      ) do
    # FIXME: this inserts a row in `individual_properties` even if the interface is datastream
    insert_path(
      realm,
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
        realm,
        device_id,
        %InterfaceDescriptor{storage_type: :one_object_datastream_dbtable} = interface_descriptor,
        mapping,
        path,
        value_timestamp,
        reception_timestamp,
        opts
      ) do
    # FIXME: this inserts a row in `individual_properties` even if the interface is datastream
    insert_path(
      realm,
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
         realm,
         device_id,
         interface_descriptor,
         mapping,
         path,
         value_timestamp,
         reception_timestamp,
         opts
       ) do
    %InterfaceDescriptor{interface_id: interface_id} = interface_descriptor
    %Mapping{endpoint_id: endpoint_id} = mapping
    keyspace_name = Realm.keyspace_name(realm)
    timestamp = div(reception_timestamp, 10000) |> DateTime.from_unix!(:microsecond)
    reception_timestamp_submillis = rem(reception_timestamp, 10000)

    # TODO: :reception_timestamp_submillis is just a place holder right now
    entry = %{
      device_id: device_id,
      interface_id: interface_id,
      endpoint_id: endpoint_id,
      path: path,
      reception_timestamp: timestamp,
      reception_timestamp_submillis: reception_timestamp_submillis,
      datetime_value: DateTime.from_unix!(value_timestamp, :microsecond)
    }

    opts =
      [
        prefix: keyspace_name,
        consistency: Consistency.device_info(:write)
      ]
      |> Keyword.merge(opts)

    # TODO: do not hardcode IndividualProperty here
    case Repo.safe_insert_all(IndividualProperty, [entry], opts) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Error while upserting path: #{path} (reason: #{inspect(reason)}).")
        {:error, :database_error}
    end
  end

  def delete_property_from_db(realm, device_id, interface_descriptor, endpoint_id, path) do
    %InterfaceDescriptor{storage: storage, interface_id: interface_id} = interface_descriptor
    keyspace_name = Realm.keyspace_name(realm)

    _ = remove_property_row(keyspace_name, storage, device_id, interface_id, endpoint_id, path)
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
      |> Repo.one(consistency: Consistency.device_info(:read))

    %{
      introspection: stats.introspection,
      total_received_msgs: stats.total_received_msgs,
      total_received_bytes: stats.total_received_bytes,
      initial_interface_exchanged_bytes: stats.exchanged_bytes_by_interface,
      initial_interface_exchanged_msgs: stats.exchanged_msgs_by_interface
    }
  end

  def set_device_connected!(realm, device_id, timestamp, ip_address) do
    set_connection_info!(realm, device_id, timestamp, ip_address)

    ttl = heartbeat_interval_seconds() * 8
    refresh_device_connected!(realm, device_id, ttl)
  end

  def maybe_refresh_device_connected!(realm, device_id) do
    with {:ok, remaining_ttl} <- get_connected_remaining_ttl(realm, device_id) do
      if remaining_ttl < heartbeat_interval_seconds() * 2 do
        Logger.debug("Refreshing connected status", tag: "refresh_device_connected")
        write_ttl = heartbeat_interval_seconds() * 8
        refresh_device_connected!(realm, device_id, write_ttl)
      else
        :ok
      end
    end
  end

  defp heartbeat_interval_seconds do
    Config.device_heartbeat_interval_ms!() |> div(1000)
  end

  defp set_connection_info!(realm, device_id, timestamp, ip_address) do
    keyspace_name = Realm.keyspace_name(realm)
    timestamp = Ecto.Type.cast!(:utc_datetime_usec, timestamp)

    %Device{device_id: device_id}
    |> Ecto.Changeset.change(
      last_connection: timestamp,
      last_seen_ip: ip_address
    )
    |> Repo.update!(prefix: keyspace_name, consistency: Consistency.device_info(:write))
  end

  defp refresh_device_connected!(realm, device_id, ttl) do
    keyspace_name = Realm.keyspace_name(realm)

    changeset =
      %Device{device_id: device_id}
      |> Ecto.Changeset.change(connected: true)

    opts = [prefix: keyspace_name, ttl: ttl, consistency: Consistency.device_info(:write)]

    # We use `insert` here becuase Exandra does not support ttl on updates. However, this is an upsert in Scylla.
    Repo.insert!(changeset, opts)
  end

  defp get_connected_remaining_ttl(realm, device_id) do
    keyspace_name = Realm.keyspace_name(realm)

    query =
      Device
      |> where(device_id: ^device_id)
      |> select([device], fragment("TTL(?)", device.connected))
      |> put_query_prefix(keyspace_name)

    case Repo.fetch_one(query, consistency: Consistency.device_info(:read)) do
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
        realm,
        device_id,
        timestamp_ms,
        total_received_msgs,
        total_received_bytes,
        interface_exchanged_msgs,
        interface_exchanged_bytes
      ) do
    keyspace_name = Realm.keyspace_name(realm)
    timestamp_ms = Ecto.Type.cast!(:utc_datetime_usec, timestamp_ms)

    changeset =
      %Device{device_id: device_id}
      |> Ecto.Changeset.change(
        connected: false,
        last_disconnection: timestamp_ms,
        total_received_msgs: total_received_msgs,
        total_received_bytes: total_received_bytes,
        exchanged_bytes_by_interface: interface_exchanged_bytes,
        exchanged_msgs_by_interface: interface_exchanged_msgs
      )

    opts = [prefix: keyspace_name, consistency: Consistency.device_info(:write)]

    Repo.update!(changeset, opts)
  end

  def fetch_device_introspection_minors(realm, device_id) do
    keyspace_name = Realm.keyspace_name(realm)

    query =
      Device
      |> select([d], d.introspection_minor)
      |> where(device_id: ^device_id)
      |> put_query_prefix(keyspace_name)

    consistency = Consistency.device_info(:read)

    with minors when is_map(minors) <- Repo.fetch_one(query, consistency: consistency) do
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

    consistency = Consistency.device_info(:read)

    with groups when is_map(groups) <- Repo.fetch_one(query, consistency: consistency) do
      {:ok, Map.keys(groups)}
    end
  end

  def update_device_introspection!(realm, device_id, introspection, introspection_minor) do
    keyspace_name = Realm.keyspace_name(realm)

    changeset =
      %Device{device_id: device_id}
      |> Ecto.Changeset.change(
        introspection: introspection,
        introspection_minor: introspection_minor
      )

    opts = [prefix: keyspace_name, consistency: Consistency.device_info(:write)]

    Repo.update!(changeset, opts)
  end

  def add_old_interfaces(realm, device_id, old_interfaces) do
    keyspace_name = Realm.keyspace_name(realm)

    device =
      from d in Device,
        prefix: ^keyspace_name,
        where: d.device_id == ^device_id,
        update: [set: [old_introspection: fragment(" old_introspection + ?", ^old_interfaces)]]

    case Repo.safe_update_all(device, [], consistency: Consistency.device_info(:write)) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        encoded_device_id = CoreDevice.encode_device_id(device_id)

        _ =
          Logger.warning(
            "Could not update old introspection on device #{encoded_device_id}, reason: #{inspect(reason)}",
            realm: realm,
            tag: "add_old_interfaces_fail"
          )

        {:error, reason}
    end
  end

  def remove_old_interfaces(realm, device_id, old_interfaces) do
    keyspace_name = Realm.keyspace_name(realm)

    old_interfaces = MapSet.new(old_interfaces)

    device =
      from d in Device,
        prefix: ^keyspace_name,
        where: d.device_id == ^device_id,
        update: [set: [old_introspection: fragment(" old_introspection - ?", ^old_interfaces)]]

    case Repo.safe_update_all(device, [], consistency: Consistency.device_info(:write)) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        encoded_device_id = CoreDevice.encode_device_id(device_id)

        _ =
          Logger.warning(
            "Could not update old introspection on device #{encoded_device_id}, reason: #{inspect(reason)}",
            realm: realm,
            tag: "remove_old_interfaces_fail"
          )

        {:error, reason}
    end
  end

  def register_device_with_interface(realm, device_id, interface_name, interface_major) do
    keyspace_name = Realm.keyspace_name(realm)
    encoded_device_id = CoreDevice.encode_device_id(device_id)

    devices_by_interface = %{
      group: "devices-by-interface-#{interface_name}-v#{interface_major}",
      key: encoded_device_id
    }

    devices_on_interface = %{
      group: "devices-with-data-on-interface-#{interface_name}-v#{interface_major}",
      key: encoded_device_id
    }

    opts = [prefix: keyspace_name, consistency: Consistency.device_info(:write)]

    with {:ok, _} <- Repo.safe_insert_all(KvStore, [devices_by_interface], opts),
         {:ok, _} <- Repo.safe_insert_all(KvStore, [devices_on_interface], opts) do
      :ok
    else
      {:error, reason} ->
        Logger.warning(
          "Database error: cannot register device-interface pair, reason: #{inspect(reason)}."
        )

        {:error, reason}
    end
  end

  def unregister_device_with_interface(realm, device_id, interface_name, interface_major) do
    keyspace_name = Realm.keyspace_name(realm)
    group = "devices-by-interface-#{interface_name}-v#{interface_major}"
    encoded_device_id = CoreDevice.encode_device_id(device_id)

    query =
      from(KvStore)
      |> where(group: ^group, key: ^encoded_device_id)
      |> put_query_prefix(keyspace_name)

    case Repo.safe_delete_all(query, consistency: Consistency.device_info(:write)) do
      {:ok, _} ->
        :ok

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

    case Repo.fetch_one(query, consistency: Consistency.device_info(:read)) do
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

    column_name = CQLUtils.type_to_db_column_name(value_type) |> String.to_existing_atom()
    keyspace_name = Realm.keyspace_name(realm)

    from(storage)
    |> select(^[:path, column_name])
    |> where(device_id: ^device_id, interface_id: ^interface_id, endpoint_id: ^endpoint_id)
    |> put_query_prefix(keyspace_name)
    |> Repo.all(consistency: Consistency.device_info(:read))
  end

  def fetch_datastream_maximum_storage_retention(realm) do
    keyspace_name = Realm.keyspace_name(realm)

    query =
      KvStore
      |> where(group: "realm_config", key: "datastream_maximum_storage_retention")
      |> select([v], fragment("blobAsInt(?)", v.value))
      |> put_query_prefix(keyspace_name)

    consistency = Consistency.domain_model(:read)

    with n when is_number(n) or is_nil(n) <- Repo.fetch_one(query, consistency: consistency) do
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
      |> select([p], fragment("TTL(?)", p.datetime_value))

    consistency = Consistency.device_info(:read)

    case Repo.fetch_all(q, consistency: consistency) do
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
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from(d in DeletionInProgress,
        prefix: ^keyspace_name,
        where: d.device_id == ^device_id,
        update: [set: [dup_end_ack: true]]
      )

    consistency = Consistency.device_info(:write)

    with {:ok, _} <- Repo.safe_update_all(query, [], consistency: consistency) do
      :ok
    end
  end

  def ack_start_device_deletion(realm_name, device_id) do
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from(d in DeletionInProgress,
        prefix: ^keyspace_name,
        where: d.device_id == ^device_id,
        update: [set: [dup_start_ack: true]]
      )

    consistency = Consistency.device_info(:write)

    with {:ok, _} <- Repo.safe_update_all(query, [], consistency: consistency) do
      :ok
    end
  end

  def check_device_deletion_in_progress(realm_name, device_id) do
    keyspace_name = Realm.keyspace_name(realm_name)

    Xandra.Cluster.run(
      :xandra,
      &do_check_device_deletion_in_progress(&1, keyspace_name, device_id)
    )
  end

  defp do_check_device_deletion_in_progress(conn, realm_name, device_id) do
    statement = """
    SELECT *
    FROM #{realm_name}.deletion_in_progress
    WHERE device_id = :device_id
    """

    opts = [
      consistency: Consistency.device_info(:read),
      uuid_format: :binary
    ]

    with {:ok, prepared} <- Xandra.prepare(conn, statement),
         {:ok, %Xandra.Page{} = page} <-
           Xandra.execute(conn, prepared, %{"device_id" => device_id}, opts) do
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
        &Xandra.execute!(&1, statement, %{}, consistency: Consistency.domain_model(:read))
      )

    Enum.to_list(realms)
  end

  def retrieve_devices_waiting_to_start_deletion!(realm_name) do
    keyspace_name = Realm.keyspace_name(realm_name)

    Xandra.Cluster.run(
      :xandra,
      &do_retrieve_devices_waiting_to_start_deletion!(&1, keyspace_name)
    )
  end

  defp do_retrieve_devices_waiting_to_start_deletion!(conn, realm_name) do
    statement = """
    SELECT *
    FROM #{realm_name}.deletion_in_progress
    """

    Xandra.execute!(conn, statement, %{},
      consistency: Consistency.device_info(:read),
      uuid_format: :binary
    )
    |> Enum.to_list()
  end
end
