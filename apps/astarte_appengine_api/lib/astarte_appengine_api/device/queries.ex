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
  alias Astarte.AppEngine.API.Device.DeletionInProgress
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.AppEngine.API.Device.InterfaceValuesOptions
  alias Astarte.AppEngine.API.Device.InterfaceInfo
  alias Astarte.AppEngine.API.KvStore
  alias Astarte.AppEngine.API.Name
  alias Astarte.AppEngine.API.Repo
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult
  alias Astarte.AppEngine.API.Realm
  alias Astarte.AppEngine.API.Devices.Device, as: DatabaseDevice
  alias Astarte.AppEngine.API.Endpoint, as: DatabaseEndpoint

  require CQEx
  require Logger

  def first_result_row(values) do
    DatabaseResult.head(values)
  end

  def retrieve_interfaces_list(realm_name, device_id) do
    keyspace = keyspace_name(realm_name)

    query =
      from d in DatabaseDevice,
        prefix: ^keyspace,
        select: d.introspection

    with {:ok, introspection} <- Repo.fetch(query, device_id, error: :device_not_found) do
      interfaces_list = introspection |> Map.keys()
      {:ok, interfaces_list}
    end
  end

  def retrieve_all_endpoint_ids_for_interface!(realm_name, interface_id, opts \\ []) do
    keyspace = keyspace_name(realm_name)

    query =
      from DatabaseEndpoint,
        prefix: ^keyspace,
        where: [interface_id: ^interface_id],
        select: [:value_type, :endpoint_id]

    query =
      case opts[:limit] do
        nil -> query
        limit -> query |> limit(^limit)
      end

    Repo.all(query)
  end

  def retrieve_all_endpoints_for_interface!(realm_name, interface_id) do
    keyspace = keyspace_name(realm_name)

    query =
      from DatabaseEndpoint,
        prefix: ^keyspace,
        where: [interface_id: ^interface_id],
        select: [:value_type, :endpoint]

    Repo.all(query)
  end

  def retrieve_mapping(realm_name, interface_id, endpoint_id) do
    keyspace = keyspace_name(realm_name)

    query =
      from DatabaseEndpoint,
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

    Repo.get_by!(query, [interface_id: interface_id, endpoint_id: endpoint_id], prefix: keyspace)
  end

  def interface_has_explicit_timestamp?(realm_name, interface_id) do
    keyspace = keyspace_name(realm_name)
    do_interface_has_explicit_timestamp?(keyspace, interface_id)
  end

  def do_interface_has_explicit_timestamp?(keyspace, interface_id) do
    interface_explicit_timestamp =
      from(d in DatabaseEndpoint,
        where: [interface_id: ^interface_id],
        select: d.explicit_timestamp,
        limit: 1
      )
      |> Repo.one!(prefix: keyspace)

    # ensure boolean value
    with nil <- interface_explicit_timestamp do
      false
    end
  end

  def fetch_datastream_maximum_storage_retention(realm_name) do
    keyspace = keyspace_name(realm_name)
    group = "realm_config"
    key = "datastream_maximum_storage_retention"

    case KvStore.fetch_value(group, key, :integer, consistency: :quorum, prefix: keyspace) do
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

    opts = %{opts | limit: 1}

    do_get_datastream_values(realm_name, device_id, interface_row, endpoint_id, path, opts)
    |> select(^columns)
    |> Repo.fetch_one()
  end

  def retrieve_all_endpoint_paths!(realm_name, device_id, interface_id, endpoint_id) do
    find_endpoints(realm_name, "individual_properties", device_id, interface_id, endpoint_id)
    |> select([:path])
    |> Repo.all()
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
      |> DatabaseQuery.put(:reception_timestamp_submillis, rem(reception_timestamp, 1000))
      |> DatabaseQuery.put(:datetime_value, value_timestamp)

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  # TODO Copy&pasted from data updater plant, make it a library
  def insert_value_into_db(
        realm_name,
        _db_client,
        device_id,
        %InterfaceDescriptor{storage_type: :multi_interface_individual_properties_dbtable} =
          interface_descriptor,
        endpoint_id,
        endpoint,
        path,
        nil,
        _timestamp,
        _opts
      ) do
    if endpoint.allow_unset == false do
      _ =
        Logger.warning("Tried to unset value on allow_unset=false mapping.",
          tag: "unset_not_allowed"
        )

      # TODO: should we handle this situation?
    end

    # TODO: :reception_timestamp_submillis is just a place holder right now
    %InterfaceDescriptor{interface_id: interface_id, storage: storage} = interface_descriptor
    keyspace_name = Realm.keyspace_name(realm_name)

    q =
      from v in storage,
        prefix: ^keyspace_name,
        where:
          v.device_id == ^device_id and v.interface_id == ^interface_id and
            v.endpoint_id == ^endpoint_id and v.path == ^path

    with {0, _} <- Repo.delete_all(q) do
      Logger.warning(
        "Could not unset value for  #{Device.encode_device_id(device_id)} in #{storage}}",
        realm: "realm",
        tag: "cant_unset"
      )
    end

    :ok
  end

  # TODO Copy&pasted from data updater plant, make it a library
  def insert_value_into_db(
        _realm_name,
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
        _realm_name,
        db_client,
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
      |> DatabaseQuery.put(:reception_timestamp_submillis, rem(timestamp, 1000))
      |> DatabaseQuery.put(:value, to_db_friendly_type(value))

    # TODO: |> DatabaseQuery.consistency(insert_consistency(interface_descriptor, endpoint))

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  # TODO Copy&pasted from data updater plant, make it a library
  def insert_value_into_db(
        realm_name,
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
    keyspace = keyspace_name(realm_name)
    interface_id = interface_descriptor.interface_id

    endpoint_rows =
      from(DatabaseEndpoint,
        where: [interface_id: ^interface_id],
        select: [:endpoint, :value_type]
      )
      |> Repo.all(prefix: keyspace)

    explicit_timestamp = do_interface_has_explicit_timestamp?(keyspace, interface_id)

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
      |> DatabaseQuery.put(:reception_timestamp_submillis, rem(timestamp, 1000))
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

  def retrieve_device_status(realm_name, device_id) do
    keyspace = keyspace_name(realm_name)
    fields = [:device_id | @device_status_columns_without_device_id]

    query = from(DatabaseDevice, prefix: ^keyspace, select: ^fields)

    with {:ok, device} <- Repo.fetch(query, device_id, error: :device_not_found) do
      {:ok, build_device_status(keyspace, device)}
    end
  end

  defp deletion_in_progress?(keyspace, device_id) do
    case Repo.fetch(DeletionInProgress, device_id, prefix: keyspace) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  def retrieve_devices_list(realm_name, limit, retrieve_details?, previous_token) do
    keyspace = keyspace_name(realm_name)

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
      |> Repo.all()

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
    keyspace = keyspace_name(realm_name)
    do_device_alias_to_device_id(keyspace, device_alias)
  end

  defp do_device_alias_to_device_id(keyspace, device_alias) do
    query =
      from d in Name,
        prefix: ^keyspace,
        select: d.object_uuid,
        where: d.object_type == 1 and d.object_name == ^device_alias

    Repo.fetch_one(query, consistency: :quorum, error: :device_not_found)
  end

  def insert_attribute(realm_name, device_id, attribute_key, attribute_value) do
    keyspace = keyspace_name(realm_name)
    new_attribute = %{attribute_key => attribute_value}

    query =
      from d in DatabaseDevice,
        prefix: ^keyspace,
        where: d.device_id == ^device_id,
        update: [set: [attributes: fragment("attributes + ?", ^new_attribute)]]

    Repo.update_all(query, [], consistency: :each_quorum)

    :ok
  end

  def delete_attribute(realm_name, device_id, attribute_key) do
    keyspace = keyspace_name(realm_name)
    query = from(d in DatabaseDevice, select: d.attributes)
    opts = [prefix: keyspace, consistency: :quorum]

    with {:ok, attributes} <- Repo.fetch(query, device_id, opts),
         {:ok, _} <- get_value(attributes, attribute_key, :attribute_key_not_found) do
      map_new_attribute = MapSet.new([attribute_key])

      query_delete_attributes =
        from DatabaseDevice,
          prefix: ^keyspace,
          where: [device_id: ^device_id],
          update: [set: [attributes: fragment("attributes - ?", ^map_new_attribute)]]

      with {0, _} <- Repo.update_all(query_delete_attributes, [], consistency: :each_quorum) do
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
    keyspace = keyspace_name(realm_name)
    names_table = Name.__schema__(:source)

    insert_alias_to_names_statement = """
    INSERT INTO #{keyspace}.#{names_table}
    (object_name, object_type, object_uuid)
    VALUES (?, 1, ?)
    """

    insert_alias_to_names_params = [alias_value, device_id]
    insert_alias_to_names_query = {insert_alias_to_names_statement, insert_alias_to_names_params}

    new_alias = %{alias_tag => alias_value}

    insert_alias_to_device =
      from DatabaseDevice,
        prefix: ^keyspace,
        where: [device_id: ^device_id],
        update: [set: [aliases: fragment("aliases + ?", ^new_alias)]]

    insert_alias_to_device_query = Repo.to_sql(:update_all, insert_alias_to_device)

    insert_batch =
      %Exandra.Batch{queries: [insert_alias_to_names_query, insert_alias_to_device_query]}

    with {:existing, {:error, :device_not_found}} <-
           {:existing, device_alias_to_device_id(realm_name, alias_value)},
         :ok <- try_delete_alias(realm_name, device_id, alias_tag),
         :ok <- Exandra.execute_batch(Repo, insert_batch, consistency: :each_quorum) do
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
    keyspace = keyspace_name(realm_name)

    query =
      from d in DatabaseDevice,
        select: d.aliases

    opts = [prefix: keyspace, consistency: :quorum, error: :device_not_found]

    with {:ok, result} <- Repo.fetch(query, device_id, opts),
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
        from(d in Name,
          prefix: ^keyspace,
          where: [object_name: ^alias_value, object_type: 1]
        )

      sql_query_delete_in_name = Repo.to_sql(:delete_all, query_delete_in_name)

      update_and_delete_batch =
        %Exandra.Batch{queries: [sql_query_delete_alias, sql_query_delete_in_name]}

      Exandra.execute_batch(Repo, update_and_delete_batch, consistency: :each_quorum)
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
    keyspace = keyspace_name(realm_name)

    query =
      from DatabaseDevice,
        prefix: ^keyspace,
        update: [set: [inhibit_credentials_request: ^inhibit_credentials_request]],
        where: [device_id: ^device_id]

    Repo.update_all(query, [], consistency: :each_quorum)

    :ok
  end

  def retrieve_object_datastream_values(realm_name, device_id, interface_row, path, columns, opts) do
    keyspace = keyspace_name(realm_name)

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

    values = query |> select(^columns) |> Repo.all()
    count = query |> select([d], count(field(d, ^timestamp_column))) |> Repo.one()

    {count, values}
  end

  def get_results_count(_client, _count_query, %InterfaceValuesOptions{downsample_to: nil}) do
    # Count will be ignored since there's no downsample_to
    nil
  end

  def get_results_count(client, count_query, opts) do
    with {:ok, result} <- DatabaseQuery.call(client, count_query),
         [{_count_key, count}] <- DatabaseResult.head(result) do
      limit = opts.limit || Config.max_results_limit!()

      min(count, limit)
    else
      error ->
        _ =
          Logger.warning("Can't retrieve count for #{inspect(count_query)}: #{inspect(error)}.",
            tag: "db_error"
          )

        nil
    end
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

    find_endpoints(
      realm_name,
      interface_row.storage,
      device_id,
      interface_row.interface_id,
      endpoint_id
    )
    |> select(^columns)
    |> Repo.all()
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

    query =
      do_get_datastream_values(realm_name, device_id, interface_row, endpoint_id, path, opts)

    values = query |> select(^columns) |> Repo.all()
    count = query |> select([d], count(d.value_timestamp)) |> Repo.one!()

    {count, values}
  end

  def value_type_query(realm_name, interface_id, endpoint_id) do
    keyspace = keyspace_name(realm_name)
    query = from DatabaseEndpoint, select: [:value_type]

    Repo.get_by!(query, [interface_id: interface_id, endpoint_id: endpoint_id], prefix: keyspace)
  end

  defp do_get_datastream_values(
         realm_name,
         device_id,
         interface_row,
         endpoint_id,
         path,
         opts
       ) do
    keyspace = keyspace_name(realm_name)

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

  defp find_endpoints(realm_name, table_name, device_id, interface_id, endpoint_id) do
    keyspace = keyspace_name(realm_name)

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

  defp keyspace_name(realm_name) do
    Astarte.Core.CQLUtils.realm_name_to_keyspace_name(
      realm_name,
      Astarte.DataAccess.Config.astarte_instance_id!()
    )
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

    deletion_in_progress? = deletion_in_progress?(keyspace, device_id)

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
