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
  alias Astarte.Core.CQLUtils

  alias Astarte.DataAccess.Realms.Device, as: DatabaseDevice
  alias Astarte.DataAccess.Realms.Endpoint, as: DatabaseEndpoint
  alias Astarte.DataAccess.Realms.DeletionInProgress, as: DatabaseDeletionInProgress
  alias Astarte.DataAccess.Realms.IndividualDatastream, as: DatabaseIndividualDatastream
  alias Astarte.DataAccess.Realms.IndividualProperty, as: DatabaseIndividualProperty
  alias Astarte.DataAccess.Realms.Name, as: DatabaseName
  alias Astarte.DataAccess.Astarte.KvStore
  alias Astarte.DataAccess.Astarte.Realm

  require Logger

  def retrieve_interfaces_list(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    from DatabaseDevice,
      prefix: ^keyspace,
      select: [:introspection]
  end

  def retrieve_all_endpoint_ids_for_interface!(realm_name, interface_id) do
    keyspace = Realm.keyspace_name(realm_name)

    from DatabaseEndpoint,
      prefix: ^keyspace,
      where: [interface_id: ^interface_id],
      select: [:value_type, :endpoint_id]
  end

  def retrieve_all_endpoints_for_interface!(realm_name, interface_id) do
    keyspace = Realm.keyspace_name(realm_name)

    from DatabaseEndpoint,
      prefix: ^keyspace,
      where: [interface_id: ^interface_id],
      select: [:value_type, :endpoint]
  end

  def retrieve_mapping(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    from DatabaseEndpoint,
      prefix: ^keyspace,
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
  end

  def datastream_maximum_storage_retention(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    from k in KvStore,
      prefix: ^keyspace,
      select: fragment("blobAsInt(?)", k.value),
      where: k.group == "realm_config" and k.key == "datastream_maximum_storage_retention"
  end

  def retrieve_all_endpoint_paths!(realm_name, device_id, interface_id, endpoint_id) do
    find_endpoints(realm_name, "individual_properties", device_id, interface_id, endpoint_id)
    |> select([:path])
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

  def device_status(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)
    field_selection = [:device_id | @device_status_columns_without_device_id]

    from DatabaseDevice, prefix: ^keyspace, select: ^field_selection
  end

  def deletion_in_progress(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    from d in DatabaseDeletionInProgress, prefix: ^keyspace, select: [:device_id]
  end

  def retrieve_devices_list(realm_name, limit, retrieve_details, previous_token) do
    keyspace = Realm.keyspace_name(realm_name)

    field_selection =
      if retrieve_details do
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

    from d in DatabaseDevice,
      prefix: ^keyspace,
      select: merge(map(d, ^field_selection), %{"token" => fragment("TOKEN(?)", d.device_id)}),
      where: ^token_filter,
      limit: ^limit
  end

  def device_alias_to_device_id(realm_name, device_alias) do
    keyspace = Realm.keyspace_name(realm_name)

    from DatabaseName,
      prefix: ^keyspace,
      select: [:object_uuid],
      where: [object_type: 1, object_name: ^device_alias]
  end

  def retrieve_object_datastream_values(
        realm_name,
        device_id,
        interface_row,
        path,
        timestamp_column,
        opts
      ) do
    keyspace = Realm.keyspace_name(realm_name)

    # Check the explicit user defined limit to know if we have to reorder data
    data_ordering = if explicit_limit?(opts), do: [desc: timestamp_column], else: []
    query_limit = query_limit(opts)

    from(interface_row.storage, prefix: ^keyspace)
    |> where(device_id: ^device_id, path: ^path)
    |> filter_timestamp_range(timestamp_column, opts)
    |> order_by(^data_ordering)
    |> limit(^query_limit)
  end

  def all_properties_for_endpoint!(realm_name, device_id, interface_row, endpoint_id) do
    table = interface_row.storage
    interface_id = interface_row.interface_id
    value_type_column = Astarte.Core.CQLUtils.type_to_db_column_name(interface_row.storage_type)

    find_endpoints(realm_name, table, device_id, interface_id, endpoint_id)
    |> select(^[:path, value_type_column])
  end

  def find_endpoints(realm_name, table_name, device_id, interface_id, endpoint_id) do
    keyspace = Realm.keyspace_name(realm_name)

    from(table_name, prefix: ^keyspace)
    |> where(device_id: ^device_id, interface_id: ^interface_id, endpoint_id: ^endpoint_id)
  end

  def retrieve_datastream_values(
        realm_name,
        device_id,
        interface_row,
        endpoint_id,
        path,
        opts
      ) do
    keyspace = Realm.keyspace_name(realm_name)

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

  def value_type_query(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    from DatabaseEndpoint,
      prefix: ^keyspace,
      select: [:value_type]
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

  def endpoint_mappings(realm_name, device_id, interface_descriptor, endpoint) do
    keyspace = Realm.keyspace_name(realm_name)
    interface_id = interface_descriptor.interface_id
    endpoint_id = endpoint.endpoint_id

    from interface_descriptor.storage,
      prefix: ^keyspace,
      where: [
        device_id: ^device_id,
        interface_id: ^interface_id,
        endpoint_id: ^endpoint_id
      ]
  end

  def storage_attributes(:multi_interface_individual_datastream_dbtable, args) do
    %{
      device_id: device_id,
      interface_descriptor: interface_descriptor,
      endpoint: endpoint,
      path: path,
      timestamp: timestamp,
      value: value
    } = args

    {datetime, timestamp_sub} = timestamp_and_submillis(timestamp)
    value_column = CQLUtils.type_to_db_column_name(endpoint.value_type) |> String.to_atom()

    struct(
      DatabaseIndividualDatastream,
      %{
        value_column => value,
        device_id: device_id,
        interface_id: interface_descriptor.interface_id,
        endpoint_id: endpoint.endpoint_id,
        path: path,
        value_timestamp: datetime,
        reception_timestamp: datetime,
        reception_timestamp_submillis: timestamp_sub
      }
    )
  end

  def storage_attributes(:multi_interface_individual_properties_dbtable, args) do
    %{
      device_id: device_id,
      interface_descriptor: interface_descriptor,
      endpoint: endpoint,
      path: path,
      timestamp: timestamp,
      value: value
    } = args

    value_column = CQLUtils.type_to_db_column_name(endpoint.value_type) |> String.to_atom()

    struct(
      DatabaseIndividualProperty,
      %{
        value_column => value,
        device_id: device_id,
        interface_id: interface_descriptor.interface_id,
        endpoint_id: endpoint.endpoint_id,
        path: path,
        reception_timestamp: timestamp
      }
    )
  end

  def storage_attributes(:one_object_datastream_dbtable, args) do
    %{
      device_id: device_id,
      path: path,
      timestamp: timestamp,
      value: value,
      endpoints: endpoints,
      explicit_timestamp?: explicit_timestamp?
    } = args

    # FIXME: new atoms are created here, we should avoid this. We need to replace CQEx.
    column_meta =
      endpoints
      |> Map.new(fn endpoint ->
        endpoint_name = endpoint.endpoint |> String.split("/") |> List.last()
        column_name = CQLUtils.endpoint_to_db_column_name(endpoint_name) |> String.to_atom()
        {endpoint_name, %{name: column_name, type: endpoint.value_type}}
      end)

    timestamp = timestamp |> DateTime.to_unix(:microsecond)
    timestamp_ms = timestamp |> div(1000)
    timestamp_sub = timestamp |> rem(100)

    base_attributes = %{
      device_id: device_id,
      path: path
    }

    timestamp_attributes =
      if explicit_timestamp? do
        %{
          value_timestamp: timestamp_ms,
          reception_timestamp: timestamp_ms,
          reception_timestamp_submillis: timestamp_sub
        }
      else
        %{reception_timestamp: timestamp_ms, reception_timestamp_submillis: timestamp_sub}
      end

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

    value_attributes = value |> Map.new(fn {column, data} -> {column, data.value} end)

    base_attributes
    |> Map.merge(timestamp_attributes)
    |> Map.merge(value_attributes)
  end

  def timestamp_and_submillis(%DateTime{} = datetime) do
    timestamp_sub = datetime |> DateTime.to_unix(:microsecond) |> rem(100)
    {datetime, timestamp_sub}
  end

  def timestamp_and_submillis(timestamp) when is_integer(timestamp) do
    datetime = timestamp |> DateTime.from_unix!(:microsecond)
    timestamp_sub = timestamp |> rem(100)

    {datetime, timestamp_sub}
  end
end
