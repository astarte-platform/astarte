#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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
  import Ecto.Query

  alias Astarte.AppEngine.API.Config
  alias Astarte.AppEngine.API.DateTime, as: DateTimeMs
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.AppEngine.API.Device.InterfaceInfo
  alias Astarte.DataAccess.Realms.IndividualProperty
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Name
  alias Astarte.AppEngine.API.Repo
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.Mapping
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Devices.Device, as: DatabaseDevice
  alias Astarte.DataAccess.Consistency

  require Logger

  def retrieve_interfaces_list(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from d in DatabaseDevice,
        prefix: ^keyspace,
        select: d.introspection

    opts = [consistency: Consistency.device_info(:read), error: :device_not_found]

    with {:ok, introspection} <- Repo.fetch(query, device_id, opts) do
      interfaces_list = introspection |> Map.keys()
      {:ok, interfaces_list}
    end
  end

  def retrieve_all_endpoint_ids_for_interface!(realm_name, interface_id, opts \\ []) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from Endpoint,
        prefix: ^keyspace,
        where: [interface_id: ^interface_id],
        select: [:value_type, :endpoint_id]

    query =
      case opts[:limit] do
        nil -> query
        limit -> query |> limit(^limit)
      end

    Repo.all(query, consistency: Consistency.domain_model(:read))
  end

  def retrieve_all_endpoints_for_interface!(realm_name, interface_id) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from Endpoint,
        prefix: ^keyspace,
        where: [interface_id: ^interface_id],
        select: [:value_type, :endpoint]

    Repo.all(query, consistency: Consistency.domain_model(:read))
  end

  def retrieve_mapping(realm_name, interface_id, endpoint_id) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from Endpoint,
        select: [
          :endpoint,
          :value_type,
          :reliability,
          :retention,
          :database_retention_policy,
          :database_retention_ttl,
          :expiry,
          :allow_unset,
          :endpoint_id,
          :interface_id,
          :explicit_timestamp
        ]

    opts = [
      prefix: keyspace,
      consistency: Consistency.domain_model(:read)
    ]

    Repo.get_by!(query, [interface_id: interface_id, endpoint_id: endpoint_id], opts)
  end

  def interface_has_explicit_timestamp?(realm_name, interface_id) do
    keyspace = Realm.keyspace_name(realm_name)
    do_interface_has_explicit_timestamp?(keyspace, interface_id)
  end

  def do_interface_has_explicit_timestamp?(keyspace, interface_id) do
    interface_explicit_timestamp =
      from(d in Endpoint,
        where: [interface_id: ^interface_id],
        select: d.explicit_timestamp,
        limit: 1
      )
      |> Repo.one!(prefix: keyspace, consistency: Consistency.domain_model(:read))

    # ensure boolean value
    with nil <- interface_explicit_timestamp do
      false
    end
  end

  def fetch_datastream_maximum_storage_retention(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)
    group = "realm_config"
    key = "datastream_maximum_storage_retention"

    opts = [prefix: keyspace, consistency: Consistency.domain_model(:read)]

    case KvStore.fetch_value(group, key, :integer, opts) do
      {:ok, value} -> value
      {:error, _} -> nil
    end
  end

  def last_datastream_value!(
        realm_name,
        device_id,
        interface_row,
        endpoint_row,
        endpoint_id,
        path,
        opts
      ) do
    columns = default_endpoint_column_selection(endpoint_row)
    keyspace = Realm.keyspace_name(realm_name)

    opts = %{opts | limit: 1}

    do_get_datastream_values(keyspace, device_id, interface_row, endpoint_id, path, opts)
    |> select(^columns)
    |> Repo.fetch_one(consistency: Consistency.time_series(:read, endpoint_row))
  end

  def retrieve_all_endpoint_paths!(realm_name, device_id, interface_id, endpoint_id) do
    keyspace = Realm.keyspace_name(realm_name)

    find_endpoints(keyspace, "individual_properties", device_id, interface_id, endpoint_id)
    |> select([:path])
    |> Repo.all(consistency: Consistency.device_info(:read))
  end

  def insert_path_into_db(
        realm_name,
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

    keyspace = Realm.keyspace_name(realm_name)

    value =
      %IndividualProperty{
        device_id: device_id,
        interface_id: interface_descriptor.interface_id,
        endpoint_id: endpoint_id,
        path: path,
        reception: reception_timestamp,
        datetime_value: value_timestamp
      }

    value = value |> IndividualProperty.prepare_for_db()

    ttl = opts[:ttl]

    opts = [prefix: keyspace, ttl: ttl, consistency: Consistency.device_info(:write)]

    Repo.insert!(value, opts)

    :ok
  end

  # TODO Copy&pasted from data updater plant, make it a library
  def insert_value_into_db(
        realm_name,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_properties_dbtable} =
          interface_descriptor,
        endpoint_id,
        %Endpoint{allow_unset: true},
        path,
        nil,
        _timestamp,
        _opts
      ) do
    # TODO: :reception_timestamp_submillis is just a place holder right now
    %InterfaceDescriptor{interface_id: interface_id, storage: storage} = interface_descriptor
    keyspace_name = Realm.keyspace_name(realm_name)

    delete_match =
      from v in storage,
        prefix: ^keyspace_name,
        where:
          v.device_id == ^device_id and v.interface_id == ^interface_id and
            v.endpoint_id == ^endpoint_id and v.path == ^path

    {c, _} = Repo.delete_all(delete_match, consistency: Consistency.device_info(:write))

    if c == 0 do
      _ =
        Logger.warning(
          "Could not unset value for #{Device.encode_device_id(device_id)} in #{storage} or there was no data",
          realm: "realm",
          tag: "cant_unset"
        )
    end

    :ok
  end

  def insert_value_into_db(
        _realm_name,
        _device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_properties_dbtable} =
          _interface_descriptor,
        _endpoint_id,
        _endpoint,
        _path,
        nil,
        _timestamp,
        _opts
      ) do
    _ =
      Logger.warning("Tried to unset value on allow_unset=false mapping.",
        tag: "unset_not_allowed"
      )

    {:error, :unset_not_allowed}
  end

  # TODO Copy&pasted from data updater plant, make it a library
  def insert_value_into_db(
        realm_name,
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
    value_column = CQLUtils.type_to_db_column_name(endpoint.value_type)
    keyspace = Realm.keyspace_name(realm_name)

    {timestamp_ms, timestamp_submillis} = DateTimeMs.split_submillis(timestamp)

    # TODO: :reception_timestamp_submillis is just a place holder right now
    interface_storage_attributes = %{
      value_column => to_db_friendly_type(value),
      device_id: device_id,
      interface_id: interface_descriptor.interface_id,
      endpoint_id: endpoint_id,
      path: path,
      reception_timestamp: timestamp_ms,
      reception_timestamp_submillis: timestamp_submillis
    }

    opts = [
      prefix: keyspace,
      ttl: opts[:ttl],
      consistency: Consistency.device_info(:write)
    ]

    {1, _} =
      Repo.insert_all(interface_descriptor.storage, [interface_storage_attributes], opts)

    :ok
  end

  # TODO Copy&pasted from data updater plant, make it a library
  def insert_value_into_db(
        realm_name,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_datastream_dbtable} =
          interface_descriptor,
        _endpoint_id,
        endpoint,
        path,
        value,
        timestamp,
        opts
      ) do
    value_column = CQLUtils.type_to_db_column_name(endpoint.value_type)
    keyspace = Realm.keyspace_name(realm_name)
    {timestamp_ms, timestamp_submillis} = DateTimeMs.split_submillis(timestamp)

    attributes = %{
      value_column => to_db_friendly_type(value),
      device_id: device_id,
      interface_id: interface_descriptor.interface_id,
      endpoint_id: endpoint.endpoint_id,
      path: path,
      value_timestamp: timestamp_ms,
      reception_timestamp: timestamp_ms,
      reception_timestamp_submillis: timestamp_submillis
    }

    opts = [
      prefix: keyspace,
      ttl: opts[:ttl],
      consistency: Consistency.time_series(:write, endpoint)
    ]

    {1, _} = Repo.insert_all(interface_descriptor.storage, [attributes], opts)

    :ok
  end

  # TODO Copy&pasted from data updater plant, make it a library
  def insert_value_into_db(
        realm_name,
        device_id,
        %InterfaceDescriptor{storage_type: :one_object_datastream_dbtable} = interface_descriptor,
        _endpoint_id,
        mapping,
        path,
        value,
        timestamp,
        opts
      ) do
    keyspace = Realm.keyspace_name(realm_name)
    interface_id = interface_descriptor.interface_id

    endpoint_rows =
      from(Endpoint,
        where: [interface_id: ^interface_id],
        select: [:endpoint, :value_type]
      )
      |> Repo.all(prefix: keyspace, consistency: Consistency.domain_model(:read))

    explicit_timestamp? = do_interface_has_explicit_timestamp?(keyspace, interface_id)

    column_meta =
      endpoint_rows
      |> Map.new(fn endpoint ->
        endpoint_name = endpoint.endpoint |> String.split("/") |> List.last()
        column_name = CQLUtils.endpoint_to_db_column_name(endpoint_name)
        {endpoint_name, %{name: column_name, type: endpoint.value_type}}
      end)

    base_attributes = %{
      device_id: device_id,
      path: path
    }

    timestamp_attributes = timestamp_attributes(explicit_timestamp?, timestamp)
    value_attributes = value_attributes(column_meta, value)

    object_datastream =
      base_attributes
      |> Map.merge(timestamp_attributes)
      |> Map.merge(value_attributes)

    ttl = Keyword.get(opts, :ttl)

    opts = [
      prefix: keyspace,
      ttl: ttl,
      returning: false,
      consistency: Consistency.time_series(:write, mapping)
    ]

    Repo.insert_all(interface_descriptor.storage, [object_datastream], opts)

    :ok
  end

  defp timestamp_attributes(true = _explicit_timestamp?, timestamp) do
    {timestamp, submillis} =
      Astarte.AppEngine.API.DateTime.split_submillis(timestamp)

    %{
      value_timestamp: timestamp,
      reception_timestamp: timestamp,
      reception_timestamp_submillis: submillis
    }
  end

  defp timestamp_attributes(_nil_or_false_explicit_timestamp?, timestamp) do
    {timestamp, submillis} =
      Astarte.AppEngine.API.DateTime.split_submillis(timestamp)

    %{reception_timestamp: timestamp, reception_timestamp_submillis: submillis}
  end

  defp value_attributes(column_meta, value) do
    value =
      value
      |> Enum.flat_map(fn {key, value} ->
        # filter map
        case Map.fetch(column_meta, key) do
          {:ok, meta} ->
            %{name: name, type: type} = meta
            data = %{type: type, value: value}
            [{name, data}]

          :error ->
            Logger.warning("Unexpected object key #{inspect(key)} with value #{inspect(value)}.")

            []
        end
      end)

    value
    |> Map.new(fn {column, data} -> {column, data.value} end)
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

  @device_status_columns_without_device_id [
    :aliases,
    :introspection,
    :introspection_minor,
    :connected,
    :last_connection,
    :last_disconnection,
    :first_registration,
    :first_credentials_request,
    :last_credentials_request_ip,
    :last_seen_ip,
    :attributes,
    :total_received_msgs,
    :total_received_bytes,
    :exchanged_msgs_by_interface,
    :exchanged_bytes_by_interface,
    :groups,
    :old_introspection,
    :inhibit_credentials_request
  ]

  defp truncate_datetime(nil), do: nil
  defp truncate_datetime(datetime), do: datetime |> DateTime.truncate(:millisecond)

  defp ip_or_null_to_string(nil) do
    nil
  end

  defp ip_or_null_to_string(ip) do
    ip
    |> :inet_parse.ntoa()
    |> to_string()
  end

  def retrieve_device_for_status(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)
    do_retrieve_device_for_status(keyspace, device_id)
  end

  def retrieve_device_status(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    with {:ok, device} <- do_retrieve_device_for_status(keyspace, device_id) do
      {:ok, build_device_status(keyspace, device)}
    end
  end

  defp do_retrieve_device_for_status(keyspace, device_id) do
    fields = [:device_id | @device_status_columns_without_device_id]

    query =
      from DatabaseDevice,
        prefix: ^keyspace,
        select: ^fields

    opts = [consistency: Consistency.device_info(:read), error: :device_not_found]

    Repo.fetch(query, device_id, opts)
  end

  def deletion_in_progress?(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)
    do_deletion_in_progress?(keyspace, device_id)
  end

  defp do_deletion_in_progress?(keyspace, device_id) do
    opts = [prefix: keyspace, consistency: Consistency.device_info(:read)]

    case Repo.fetch(DeletionInProgress, device_id, opts) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  def retrieve_devices_list(realm_name, limit, retrieve_details?, previous_token) do
    keyspace = Realm.keyspace_name(realm_name)

    field_selection =
      if retrieve_details? do
        [:device_id | @device_status_columns_without_device_id]
      else
        [:device_id]
      end

    token_filter =
      case previous_token do
        nil ->
          true

        first ->
          min_token = first + 1
          dynamic([d], fragment("TOKEN(?)", d.device_id) >= ^min_token)
      end

    devices =
      from(d in DatabaseDevice,
        prefix: ^keyspace,
        select: merge(map(d, ^field_selection), %{"token" => fragment("TOKEN(?)", d.device_id)}),
        where: ^token_filter,
        limit: ^limit
      )
      |> Repo.all(consistency: Consistency.device_info(:read))

    devices_info =
      if retrieve_details? do
        devices |> Enum.map(fn device -> build_device_status(keyspace, device) end)
      else
        devices
        |> Enum.map(fn device ->
          Device.encode_device_id(device.device_id)
        end)
      end

    if Enum.count(devices) < limit || Enum.count(devices) == 0 do
      %DevicesList{devices: devices_info}
    else
      token = devices |> List.last() |> Map.fetch!("token")
      %DevicesList{devices: devices_info, last_token: token}
    end
  end

  def device_alias_to_device_id(realm_name, device_alias) do
    keyspace = Realm.keyspace_name(realm_name)
    do_device_alias_to_device_id(keyspace, device_alias)
  end

  defp do_device_alias_to_device_id(keyspace, device_alias) do
    query =
      from d in Name,
        prefix: ^keyspace,
        select: d.object_uuid,
        where: d.object_type == 1 and d.object_name == ^device_alias

    opts = [consistency: Consistency.device_info(:read), error: :device_not_found]

    Repo.fetch_one(query, opts)
  end

  def find_all_aliases(realm_name, alias_list) do
    keyspace = Realm.keyspace_name(realm_name)

    # Queries are chunked to avoid hitting scylla's `max_clustering_key_restrictions_per_query`
    alias_list
    |> Enum.chunk_every(99)
    |> Enum.map(&from(n in Name, where: n.object_type == 1 and n.object_name in ^&1))
    |> Enum.map(&Repo.all(&1, prefix: keyspace, consistency: Consistency.device_info(:read)))
    |> List.flatten()
  end

  def merge_device_status(_, _, device_status_changes, _, _)
      when map_size(device_status_changes) == 0,
      do: :ok

  def merge_device_status(realm_name, device, changes, alias_tags_to_delete, aliases_to_update) do
    keyspace = Realm.keyspace_name(realm_name)

    device_query = merge_device_status_device_query(keyspace, device.device_id, changes)

    aliases_queries =
      merge_device_status_aliases_queries(
        keyspace,
        device,
        alias_tags_to_delete,
        aliases_to_update
      )

    queries = [device_query | aliases_queries]

    consistency = Consistency.device_info(:write)

    case Exandra.execute_batch(Repo, %Exandra.Batch{queries: queries}, consistency: consistency) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Database error, reason: #{inspect(reason)}", tag: "db_error")
        {:error, :database_error}
    end
  end

  defp merge_device_status_device_query(keyspace, device_id, changes) do
    changes =
      case Map.fetch(changes, :credentials_inhibited) do
        {:ok, inhibit_credentials_request} ->
          changes
          |> Map.delete(:credentials_inhibited)
          |> Map.put(:inhibit_credentials_request, inhibit_credentials_request)

        :error ->
          changes
      end
      |> Keyword.new()

    device_query =
      from DatabaseDevice,
        prefix: ^keyspace,
        where: [device_id: ^device_id],
        update: [set: ^changes]

    Repo.to_sql(:update_all, device_query)
  end

  defp merge_device_status_aliases_queries(
         keyspace,
         device,
         alias_tags_to_delete,
         aliases_to_update
       ) do
    {update_tags, update_values} = Enum.unzip(aliases_to_update)

    all_tags = alias_tags_to_delete ++ update_tags

    tags_to_delete =
      device.aliases
      |> Enum.filter(fn {tag, _value} -> tag in all_tags end)

    # We delete both aliases we mean to delete, and also existing aliases we want to update
    # as the name is part of the primary key for the names table.
    # Queries are chunked to avoid hitting scylla's `max_clustering_key_restrictions_per_query`
    delete_queries =
      tags_to_delete
      |> Enum.map(fn {_tag, value} -> value end)
      |> Enum.chunk_every(99)
      |> Enum.map(fn alias_chunk ->
        query =
          from n in Name,
            prefix: ^keyspace,
            where: n.object_type == 1 and n.object_name in ^alias_chunk

        Repo.to_sql(:delete_all, query)
      end)

    insert_queries =
      update_values
      |> Enum.map(
        &%Name{
          object_name: &1,
          object_type: 1,
          object_uuid: device.device_id
        }
      )
      |> Enum.map(&Repo.insert_to_sql(&1, prefix: keyspace))

    delete_queries ++ insert_queries
  end

  def insert_attribute(realm_name, device_id, attribute_key, attribute_value) do
    keyspace = Realm.keyspace_name(realm_name)
    new_attribute = %{attribute_key => attribute_value}

    query =
      from d in DatabaseDevice,
        prefix: ^keyspace,
        where: d.device_id == ^device_id,
        update: [set: [attributes: fragment("attributes + ?", ^new_attribute)]]

    consistency = Consistency.device_info(:write)

    Repo.update_all(query, [], consistency: consistency)

    :ok
  end

  def delete_attribute(realm_name, device_id, attribute_key) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from d in DatabaseDevice,
        select: d.attributes

    opts = [prefix: keyspace, consistency: :quorum]

    with {:ok, attributes} <- Repo.fetch(query, device_id, opts),
         {:ok, _} <- get_value(attributes, attribute_key, :attribute_key_not_found) do
      map_new_attribute = MapSet.new([attribute_key])

      query_delete_attributes =
        from DatabaseDevice,
          prefix: ^keyspace,
          where: [device_id: ^device_id],
          update: [set: [attributes: fragment("attributes - ?", ^map_new_attribute)]]

      consistency = Consistency.device_info(:write)

      with {0, _} <- Repo.update_all(query_delete_attributes, [], consistency: consistency) do
        Logger.warning(
          "Could not unset attribute #{attribute_key} for  #{Device.encode_device_id(device_id)} }",
          realm: "#{realm_name}",
          tag: "cant_unset_attribute"
        )
      end

      :ok
    end
  end

  def insert_alias(realm_name, device_id, alias_tag, alias_value) do
    keyspace = Realm.keyspace_name(realm_name)

    name = %Name{
      object_name: alias_value,
      object_type: 1,
      object_uuid: device_id
    }

    insert_alias_to_names_query = Repo.insert_to_sql(name, prefix: keyspace)

    new_alias = %{alias_tag => alias_value}

    insert_alias_to_device =
      from DatabaseDevice,
        prefix: ^keyspace,
        where: [device_id: ^device_id],
        update: [set: [aliases: fragment("aliases + ?", ^new_alias)]]

    insert_alias_to_device_query = Repo.to_sql(:update_all, insert_alias_to_device)

    insert_batch =
      %Exandra.Batch{queries: [insert_alias_to_names_query, insert_alias_to_device_query]}

    consistency = Consistency.device_info(:write)

    with {:existing, {:error, :device_not_found}} <-
           {:existing, device_alias_to_device_id(realm_name, alias_value)},
         :ok <- try_delete_alias(realm_name, device_id, alias_tag),
         :ok <- Exandra.execute_batch(Repo, insert_batch, consistency: consistency) do
      :ok
    else
      {:existing, {:ok, _device_uuid}} ->
        {:error, :alias_already_in_use}

      {:existing, {:error, reason}} ->
        {:error, reason}

      {:error, :device_not_found} ->
        {:error, :device_not_found}
    end
  end

  def delete_alias(realm_name, device_id, alias_tag) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from d in DatabaseDevice,
        select: d.aliases

    fetch_opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read),
      error: :device_not_found
    ]

    with {:ok, result} <- Repo.fetch(query, device_id, fetch_opts),
         {:ok, alias_value} <- get_value(result, alias_tag, :alias_tag_not_found),
         :ok <- check_alias_ownership(keyspace, device_id, alias_tag, alias_value) do
      map_new_alias = MapSet.new([alias_tag])

      query_delete_alias =
        from DatabaseDevice,
          prefix: ^keyspace,
          where: [device_id: ^device_id],
          update: [set: [aliases: fragment("aliases - ?", ^map_new_alias)]]

      sql_query_delete_alias = Repo.to_sql(:update_all, query_delete_alias)

      query_delete_in_name =
        from d in Name,
          prefix: ^keyspace,
          where: [object_name: ^alias_value, object_type: 1]

      sql_query_delete_in_name = Repo.to_sql(:delete_all, query_delete_in_name)

      update_and_delete_batch =
        %Exandra.Batch{queries: [sql_query_delete_alias, sql_query_delete_in_name]}

      Exandra.execute_batch(Repo, update_and_delete_batch,
        consistency: Consistency.device_info(:write)
      )
    end
  end

  defp try_delete_alias(realm_name, device_id, alias_tag) do
    case delete_alias(realm_name, device_id, alias_tag) do
      :ok ->
        :ok

      {:error, :alias_tag_not_found} ->
        :ok

      not_ok ->
        not_ok
    end
  end

  def set_inhibit_credentials_request(realm_name, device_id, inhibit_credentials_request) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from DatabaseDevice,
        prefix: ^keyspace,
        update: [set: [inhibit_credentials_request: ^inhibit_credentials_request]],
        where: [device_id: ^device_id]

    Repo.update_all(query, [], consistency: Consistency.device_info(:write))

    :ok
  end

  def retrieve_object_datastream_values(
        _realm_name,
        _device_id,
        _interface_row,
        [],
        _path,
        _columns,
        _opts
      ) do
    # No endpoint rows means no datastream values, we can just return
    {0, []}
  end

  def retrieve_object_datastream_values(
        realm_name,
        device_id,
        interface_row,
        endpoint_rows,
        path,
        columns,
        opts
      ) do
    keyspace = Realm.keyspace_name(realm_name)

    query_limit = query_limit(opts)
    timestamp_column = timestamp_column(opts.explicit_timestamp)
    columns = [timestamp_column | columns]

    # Check the explicit user defined limit to know if we have to reorder data
    data_ordering = if explicit_limit?(opts), do: [desc: timestamp_column], else: []

    query =
      from(interface_row.storage, prefix: ^keyspace)
      |> where(device_id: ^device_id, path: ^path)
      |> filter_timestamp_range(timestamp_column, opts)
      |> order_by(^data_ordering)
      |> limit(^query_limit)

    # It is a datastream object: all endpoints have the same reliability
    mapping =
      endpoint_rows
      |> List.first()
      |> Mapping.from_db_result!()

    consistency = Consistency.time_series(:read, mapping)

    values =
      query
      |> select(^columns)
      |> Repo.all(consistency: consistency)

    count =
      query
      |> select([d], count(field(d, ^timestamp_column)))
      |> Repo.one(consistency: consistency)

    {count, values}
  end

  def all_properties_for_endpoint!(
        realm_name,
        device_id,
        interface_row,
        endpoint_row,
        endpoint_id
      ) do
    value_column = CQLUtils.type_to_db_column_name(endpoint_row.value_type) |> String.to_atom()
    columns = [:path, value_column]
    keyspace = Realm.keyspace_name(realm_name)

    find_endpoints(
      keyspace,
      interface_row.storage,
      device_id,
      interface_row.interface_id,
      endpoint_id
    )
    |> select(^columns)
    |> Repo.all(consistency: Consistency.device_info(:read))
  end

  def retrieve_datastream_values(
        realm_name,
        device_id,
        interface_row,
        endpoint_row,
        endpoint_id,
        path,
        opts
      ) do
    columns = default_endpoint_column_selection(endpoint_row)
    keyspace = Realm.keyspace_name(realm_name)

    query =
      do_get_datastream_values(keyspace, device_id, interface_row, endpoint_id, path, opts)

    mapping = Mapping.from_db_result!(endpoint_row)

    consistency = Consistency.time_series(:read, mapping)

    values =
      query
      |> select(^columns)
      |> Repo.all(consistency: consistency)

    count =
      query
      |> select([d], count(d.value_timestamp))
      |> Repo.one!(consistency: consistency)

    {count, values}
  end

  def value_type_query(realm_name, interface_id, endpoint_id) do
    keyspace = Realm.keyspace_name(realm_name)
    query = from Endpoint, select: [:value_type]

    opts = [prefix: keyspace, consistency: Consistency.domain_model(:read)]

    Repo.get_by!(query, [interface_id: interface_id, endpoint_id: endpoint_id], opts)
  end

  defp do_get_datastream_values(
         keyspace,
         device_id,
         interface_row,
         endpoint_id,
         path,
         opts
       ) do
    query_limit = query_limit(opts)

    # Check the explicit user defined limit to know if we have to reorder data
    data_ordering =
      if explicit_limit?(opts),
        do: [
          desc: :value_timestamp,
          desc: :reception_timestamp,
          desc: :reception_timestamp_submillis
        ],
        else: []

    storage_id = [
      device_id: device_id,
      interface_id: interface_row.interface_id,
      endpoint_id: endpoint_id,
      path: path
    ]

    from(interface_row.storage, prefix: ^keyspace)
    |> where(^storage_id)
    |> filter_timestamp_range(:value_timestamp, opts)
    |> order_by(^data_ordering)
    |> limit(^query_limit)
  end

  defp query_limit(opts), do: min(opts.limit, Config.max_results_limit!())

  defp explicit_limit?(opts) do
    user_defined_limit? = opts.limit != nil
    no_lower_timestamp_limit? = is_nil(opts.since) and is_nil(opts.since_after)

    user_defined_limit? and no_lower_timestamp_limit?
  end

  defp filter_timestamp_range(query, timestamp_column, query_opts) do
    filter_since =
      case {query_opts.since, query_opts.since_after} do
        {nil, nil} -> true
        {nil, since_after} -> dynamic([o], field(o, ^timestamp_column) > ^since_after)
        {since, _} -> dynamic([o], field(o, ^timestamp_column) >= ^since)
      end

    filter_to =
      case query_opts.to do
        nil -> true
        to -> dynamic([o], field(o, ^timestamp_column) < ^to)
      end

    query
    |> where(^filter_since)
    |> where(^filter_to)
  end

  defp find_endpoints(keyspace, table_name, device_id, interface_id, endpoint_id) do
    from(table_name, prefix: ^keyspace)
    |> where(device_id: ^device_id, interface_id: ^interface_id, endpoint_id: ^endpoint_id)
  end

  defp default_endpoint_column_selection do
    [
      :value_timestamp,
      :reception_timestamp,
      :reception_timestamp_submillis
    ]
  end

  defp default_endpoint_column_selection(endpoint_row) do
    value_column = CQLUtils.type_to_db_column_name(endpoint_row.value_type) |> String.to_atom()
    [value_column | default_endpoint_column_selection()]
  end

  defp timestamp_column(explicit_timestamp?) do
    case explicit_timestamp? do
      nil -> :reception_timestamp
      false -> :reception_timestamp
      true -> :value_timestamp
    end
  end

  defp clean_device_introspection(device) do
    introspection_major = device.introspection || %{}
    introspection_minor = device.introspection_minor || %{}

    major_keys = introspection_major |> Map.keys() |> MapSet.new()
    minor_keys = introspection_minor |> Map.keys() |> MapSet.new()

    corrupted = MapSet.symmetric_difference(major_keys, minor_keys) |> MapSet.to_list()

    for interface <- corrupted do
      device_id = Device.encode_device_id(device.device_id)

      Logger.error("Introspection has either major or minor, but not both. Corrupted entry?",
        interface: interface,
        device_id: device_id
      )
    end

    introspection_major = introspection_major |> Map.drop(corrupted)
    introspection_minor = introspection_minor |> Map.drop(corrupted)

    {introspection_major, introspection_minor}
  end

  defp build_device_status(keyspace, device) do
    {introspection_major, introspection_minor} = clean_device_introspection(device)

    %{
      device_id: device_id,
      aliases: aliases,
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
      groups: groups,
      old_introspection: old_introspection,
      inhibit_credentials_request: credentials_inhibited
    } = device

    introspection =
      Map.merge(introspection_major, introspection_minor, fn interface, major, minor ->
        interface_key = {interface, major}
        messages = exchanged_msgs_by_interface |> Map.get(interface_key, 0)
        bytes = exchanged_bytes_by_interface |> Map.get(interface_key, 0)

        %InterfaceInfo{
          major: major,
          minor: minor,
          exchanged_msgs: messages,
          exchanged_bytes: bytes
        }
      end)

    previous_interfaces =
      for {{interface, major}, minor} <- old_introspection do
        interface_key = {interface, major}
        msgs = exchanged_msgs_by_interface |> Map.get(interface_key, 0)
        bytes = exchanged_bytes_by_interface |> Map.get(interface_key, 0)

        %InterfaceInfo{
          name: interface,
          major: major,
          minor: minor,
          exchanged_msgs: msgs,
          exchanged_bytes: bytes
        }
      end

    groups =
      case groups do
        nil -> []
        groups -> groups |> Map.keys()
      end

    deletion_in_progress? = do_deletion_in_progress?(keyspace, device_id)

    device_id = Device.encode_device_id(device_id)
    connected = connected || false
    last_credentials_request_ip = ip_or_null_to_string(last_credentials_request_ip)
    last_seen_ip = ip_or_null_to_string(last_seen_ip)
    last_connection = truncate_datetime(last_connection)
    last_disconnection = truncate_datetime(last_disconnection)
    first_registration = truncate_datetime(first_registration)
    first_credentials_request = truncate_datetime(first_credentials_request)

    %DeviceStatus{
      id: device_id,
      aliases: aliases,
      introspection: introspection,
      connected: connected,
      deletion_in_progress: deletion_in_progress?,
      last_connection: last_connection,
      last_disconnection: last_disconnection,
      first_registration: first_registration,
      first_credentials_request: first_credentials_request,
      last_credentials_request_ip: last_credentials_request_ip,
      last_seen_ip: last_seen_ip,
      attributes: attributes,
      credentials_inhibited: credentials_inhibited,
      total_received_msgs: total_received_msgs,
      total_received_bytes: total_received_bytes,
      previous_interfaces: previous_interfaces,
      groups: groups
    }
  end

  defp get_value(nil = _collection, _key, error), do: {:error, error}

  defp get_value(collection, key, error) do
    case Map.fetch(collection, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, error}
    end
  end

  defp check_alias_ownership(keyspace, expected_device_id, alias_tag, alias_value) do
    case do_device_alias_to_device_id(keyspace, alias_value) do
      {:ok, ^expected_device_id} ->
        :ok

      _ ->
        Logger.error("Inconsistent alias for #{alias_tag}.",
          device_id: expected_device_id,
          tag: "inconsistent_alias"
        )

        {:error, :database_error}
    end
  end
end
