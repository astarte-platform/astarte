#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.AppEngine.API.Device.Data do
  @moduledoc """
  Device related data querying and manipulation 
  """

  alias Astarte.AppEngine.API.Device.AstarteValue
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.AppEngine.API.Device.InterfaceValuesOptions
  alias Astarte.AppEngine.API.Device.MapTree
  alias Astarte.AppEngine.API.Device.Queries
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.DataAccess.Astarte.Realm
  alias Astarte.DataAccess.Realms.Endpoint, as: DatabaseEndpoint
  alias Astarte.DataAccess.Realms.IndividualProperty, as: DatabaseIndividualProperty
  alias Astarte.DataAccess.Repo

  import Ecto.Query

  require Logger

  def insert_path(
        realm_name,
        device_id,
        %InterfaceDescriptor{storage_type: storage_type} = interface_descriptor,
        endpoint_id,
        path,
        reception_timestamp,
        opts
      )
      when storage_type in [
             :multi_interface_individual_datastream_dbtable,
             :one_object_datastream_dbtable
           ] do
    keyspace = Realm.keyspace_name(realm_name)

    ttl = Keyword.get(opts, :ttl)
    opts = [prefix: keyspace, ttl: ttl]

    {reception_timestamp, timestamp_sub} = Queries.timestamp_and_submillis(reception_timestamp)

    # TODO: use received value_timestamp when needed
    # TODO: :reception_timestamp_submillis is just a place holder right now
    %DatabaseIndividualProperty{
      device_id: device_id,
      interface_id: interface_descriptor.interface_id,
      endpoint_id: endpoint_id,
      path: path,
      reception_timestamp: reception_timestamp,
      reception_timestamp_submillis: timestamp_sub,
      datetime_value: reception_timestamp
    }
    |> Repo.insert!(opts)

    :ok
  end

  def insert_value(
        realm_name,
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
        Logger.warning("Tried to unset value on allow_unset=false mapping.",
          tag: "unset_not_allowed"
        )

      # TODO: should we handle this situation?
    end

    mapping =
      Queries.endpoint_mappings(realm_name, device_id, interface_descriptor, endpoint)
      |> where(path: ^path)

    Repo.delete_all(mapping)

    :ok
  end

  def insert_value(
        realm_name,
        device_id,
        %InterfaceDescriptor{storage_type: storage_type} = interface_descriptor,
        _endpoint_id,
        endpoint,
        path,
        value,
        timestamp,
        opts
      )
      when storage_type in [
             :multi_interface_individual_properties_dbtable,
             :multi_interface_individual_datastream_dbtable
           ] do
    keyspace = Realm.keyspace_name(realm_name)
    ttl = Keyword.get(opts, :ttl)
    # TODO: consistency = insert_consistency(interface_descriptor, endpoint)
    opts = [prefix: keyspace, ttl: ttl]

    args =
      %{
        device_id: device_id,
        interface_descriptor: interface_descriptor,
        endpoint: endpoint,
        path: path,
        timestamp: timestamp,
        value: value
      }

    entry = Queries.storage_attributes(storage_type, args)

    Repo.insert(entry, opts)
    :ok
  end

  def insert_value(
        realm_name,
        device_id,
        %InterfaceDescriptor{storage_type: storage_type} = interface_descriptor,
        _endpoint_id,
        _mapping,
        path,
        value,
        timestamp,
        opts
      )
      when storage_type == :one_object_datastream_dbtable do
    keyspace = Realm.keyspace_name(realm_name)

    interface_id = interface_descriptor.interface_id

    endpoints =
      from(DatabaseEndpoint, prefix: ^keyspace)
      |> select([:endpoint, :value_type])
      |> where(interface_id: ^interface_id)
      |> Repo.all()

    explicit_timestamp? =
      from(DatabaseEndpoint, prefix: ^keyspace)
      |> select([e], e.explicit_timestamp)
      |> where(interface_id: ^interface_id)
      |> limit(1)
      |> Repo.one()

    args = %{
      device_id: device_id,
      path: path,
      timestamp: timestamp,
      value: value,
      endpoints: endpoints,
      explicit_timestamp?: explicit_timestamp?
    }

    object_datastream = Queries.storage_attributes(storage_type, args)

    ttl = Keyword.get(opts, :ttl)
    # TODO: consistency = insert_consistency(interface_descriptor, endpoint)
    opts = [prefix: keyspace, ttl: ttl, returning: false]

    Repo.insert_all(interface_descriptor.storage, [object_datastream], opts)

    :ok
  end

  def endpoint_values(
        realm_name,
        device_id,
        :individual,
        :datastream,
        interface_row,
        endpoint_id,
        endpoint_row,
        "/",
        opts
      ) do
    path = "/"
    interface_id = interface_row.interface_id

    value_column =
      CQLUtils.type_to_db_column_name(endpoint_row.value_type) |> String.to_atom()

    columns = default_endpoint_column_selection(value_column)

    values =
      Queries.retrieve_all_endpoint_paths!(realm_name, device_id, interface_id, endpoint_id)
      |> Repo.all()
      |> Enum.filter(fn endpoint -> endpoint[:path] |> String.starts_with?(path) end)
      |> Enum.reduce(%{}, fn row, values_map ->
        last_value =
          Queries.retrieve_datastream_values(
            realm_name,
            device_id,
            interface_row,
            endpoint_id,
            row.path,
            %{opts | limit: 1}
          )
          |> select(^columns)

        case Repo.fetch_one(last_value) do
          {:ok, value} ->
            %{^value_column => v, value_timestamp: tstamp, reception_timestamp: reception} = value
            simplified_path = simplify_path(path, row.path)

            nice_value =
              AstarteValue.to_json_friendly(
                v,
                endpoint_row.value_type,
                fetch_biginteger_opts_or_default(opts)
              )

            Map.put(values_map, simplified_path, %{
              "value" => nice_value,
              "timestamp" =>
                AstarteValue.to_json_friendly(
                  tstamp,
                  :datetime,
                  keep_milliseconds: opts.keep_milliseconds
                ),
              "reception_timestamp" =>
                AstarteValue.to_json_friendly(
                  reception,
                  :datetime,
                  keep_milliseconds: opts.keep_milliseconds
                )
            })

          {:error, _reason} ->
            %{}
        end
      end)

    values
  end

  def endpoint_values(
        realm_name,
        device_id,
        :object,
        :datastream,
        interface_row,
        nil,
        endpoint_row,
        "/",
        opts
      ) do
    path = "/"

    interface_id = interface_row.interface_id

    endpoint_id = CQLUtils.endpoint_id(interface_row.name, interface_row.major_version, "")

    {count, paths} =
      Queries.retrieve_all_endpoint_paths!(realm_name, device_id, interface_id, endpoint_id)
      |> Repo.all()
      |> Enum.reduce({0, []}, fn row, {count, all_paths} ->
        if String.starts_with?(row[:path], path) do
          {count + 1, [row.path | all_paths]}
        else
          {count, all_paths}
        end
      end)

    cond do
      count == 0 ->
        {:error, :path_not_found}

      count == 1 ->
        [only_path] = paths

        with {:ok,
              %Astarte.AppEngine.API.Device.InterfaceValues{data: values, metadata: metadata}} <-
               endpoint_values(
                 realm_name,
                 device_id,
                 :object,
                 :datastream,
                 interface_row,
                 endpoint_id,
                 endpoint_row,
                 only_path,
                 opts
               ),
             {:ok, interface_values} <-
               get_interface_values_from_path(values, metadata, path, only_path) do
          {:ok, interface_values}
        else
          err ->
            Logger.warning("An error occurred while retrieving endpoint values: #{inspect(err)}",
              tag: "retrieve_endpoint_values_error"
            )

            err
        end

      count > 1 ->
        values_map =
          Enum.reduce(paths, %{}, fn a_path, values_map ->
            {:ok, %Astarte.AppEngine.API.Device.InterfaceValues{data: values}} =
              endpoint_values(
                realm_name,
                device_id,
                :object,
                :datastream,
                interface_row,
                endpoint_id,
                endpoint_row,
                a_path,
                %{opts | limit: 1}
              )

            case values do
              [] ->
                values_map

              [value] ->
                simplified_path = simplify_path(path, a_path)

                Map.put(values_map, simplified_path, value)
            end
          end)
          |> MapTree.inflate_tree()

        {:ok, %InterfaceValues{data: values_map}}
    end
  end

  def endpoint_values(
        realm_name,
        device_id,
        :object,
        :datastream,
        interface_row,
        _endpoint_id,
        endpoint_rows,
        path,
        opts
      ) do
    # FIXME: reading result wastes atoms: new atoms are allocated every time a new table is seen
    # See cqerl_protocol.erl:330 (binary_to_atom), strings should be used when dealing with large schemas
    # https://github.com/elixir-ecto/ecto/pull/4384
    endpoints =
      endpoint_rows
      |> Enum.map(
        &%{
          column: &1.endpoint |> CQLUtils.endpoint_to_db_column_name() |> String.to_atom(),
          pretty_name: &1.endpoint |> String.split("/") |> List.last(),
          value_type: &1.value_type
        }
      )

    metadata = fn endpoint -> Map.take(endpoint, [:pretty_name, :value_type]) end
    columns = endpoints |> Enum.map(& &1.column)
    endpoint_metadata = endpoints |> Map.new(&{&1.column, metadata.(&1)})

    # The old implementation used the latest element it found for the downsample column.
    # Could we just drop the reverse and consider the first instead?
    downsample_column =
      endpoints
      |> Enum.reverse()
      |> Enum.find_value(&(&1.pretty_name == opts.downsample_key && &1.column))

    timestamp_column = timestamp_column(opts.explicit_timestamp)
    columns = [timestamp_column | columns]

    query =
      Queries.retrieve_object_datastream_values(
        realm_name,
        device_id,
        interface_row,
        path,
        timestamp_column,
        opts
      )

    values = query |> select(^columns) |> Repo.all()
    count = query |> select([d], count(field(d, ^timestamp_column))) |> Repo.one!()

    values
    |> maybe_downsample_to(count, :object, nil, %InterfaceValuesOptions{
      opts
      | downsample_key: downsample_column
    })
    |> pack_result(:object, :datastream, endpoint_metadata, opts)
  end

  def endpoint_values(
        realm_name,
        device_id,
        :individual,
        :datastream,
        interface_row,
        endpoint_id,
        endpoint_row,
        path,
        opts
      ) do
    query =
      Queries.retrieve_datastream_values(
        realm_name,
        device_id,
        interface_row,
        endpoint_id,
        path,
        opts
      )

    value_column =
      CQLUtils.type_to_db_column_name(endpoint_row.value_type) |> String.to_atom()

    columns = default_endpoint_column_selection(value_column)

    values = query |> select(^columns) |> Repo.all()
    count = query |> select([d], count(d.value_timestamp)) |> Repo.one!()

    values
    |> maybe_downsample_to(count, :individual, value_column, opts)
    |> pack_result(:individual, :datastream, endpoint_row, path, opts)
  end

  def endpoint_values(
        realm_name,
        device_id,
        :individual,
        :properties,
        interface_row,
        endpoint_id,
        endpoint_row,
        path,
        opts
      ) do
    table_name = interface_row.storage
    interface_id = interface_row.interface_id

    value_column =
      CQLUtils.type_to_db_column_name(endpoint_row.value_type) |> String.to_atom()

    values =
      Queries.find_endpoints(
        realm_name,
        table_name,
        device_id,
        interface_id,
        endpoint_id
      )
      |> select(^[:path, value_column])
      |> Repo.all()
      |> Enum.filter(&String.starts_with?(&1.path, path))
      |> Enum.reduce(%{}, fn row, values_map ->
        %{^value_column => value, path: row_path} = row

        simplified_path = simplify_path(path, row_path)

        nice_value =
          AstarteValue.to_json_friendly(
            value,
            endpoint_row.value_type,
            fetch_biginteger_opts_or_default(opts)
          )

        Map.put(values_map, simplified_path, nice_value)
      end)

    values
  end

  # TODO: optimize: do not use string replace
  defp simplify_path(base_path, path) do
    no_basepath = String.replace_prefix(path, base_path, "")

    case no_basepath do
      "/" <> noleadingslash -> noleadingslash
      already_noleadingslash -> already_noleadingslash
    end
  end

  defp default_endpoint_column_selection do
    [
      :value_timestamp,
      :reception_timestamp,
      :reception_timestamp_submillis
    ]
  end

  defp default_endpoint_column_selection(value_column) do
    [value_column | default_endpoint_column_selection()]
  end

  defp get_interface_values_from_path([], _metadata, _path, _only_path) do
    {:ok, %InterfaceValues{data: %{}}}
  end

  defp get_interface_values_from_path(values, metadata, path, only_path) when is_list(values) do
    simplified_path = simplify_path(path, only_path)

    case simplified_path do
      "" ->
        {:ok, %InterfaceValues{data: values, metadata: metadata}}

      _ ->
        values_map =
          %{simplified_path => values}
          |> MapTree.inflate_tree()

        {:ok, %InterfaceValues{data: values_map, metadata: metadata}}
    end
  end

  defp get_interface_values_from_path(values, metadata, _path, _only_path) do
    {:ok, %InterfaceValues{data: values, metadata: metadata}}
  end

  defp maybe_downsample_to(values, _count, _aggregation, _value_column, %InterfaceValuesOptions{
         downsample_to: nil
       }) do
    values
  end

  defp maybe_downsample_to(values, nil, _aggregation, _value_column, _opts) do
    # TODO: we can't downsample an object without a valid count, propagate an error changeset
    # when we start using changeset consistently here
    _ = Logger.warning("No valid count in maybe_downsample_to.", tag: "downsample_invalid_count")
    values
  end

  defp maybe_downsample_to(values, _count, :object, _value_column, %InterfaceValuesOptions{
         downsample_key: nil
       }) do
    # TODO: we can't downsample an object without downsample_key, propagate an error changeset
    # when we start using changeset consistently here
    _ =
      Logger.warning("No valid downsample_key found in maybe_downsample_to.",
        tag: "downsample_invalid_key"
      )

    values
  end

  defp maybe_downsample_to(values, count, :object, _value_column, %InterfaceValuesOptions{
         downsample_to: downsampled_size,
         downsample_key: downsample_key,
         explicit_timestamp: explicit_timestamp
       })
       when downsampled_size > 2 do
    timestamp_column = timestamp_column(explicit_timestamp)
    avg_bucket_size = max(1, (count - 2) / (downsampled_size - 2))

    sample_to_x_fun = fn sample ->
      sample |> Map.fetch!(timestamp_column) |> DateTime.to_unix(:millisecond)
    end

    sample_to_y_fun = fn sample -> Map.fetch!(sample, downsample_key) end
    xy_to_sample_fun = fn x, y -> [{timestamp_column, x}, {downsample_key, y}] end

    ExLTTB.Stream.downsample(
      values,
      avg_bucket_size,
      sample_to_x_fun: sample_to_x_fun,
      sample_to_y_fun: sample_to_y_fun,
      xy_to_sample_fun: xy_to_sample_fun
    )
  end

  defp maybe_downsample_to(values, count, :individual, value_column, %InterfaceValuesOptions{
         downsample_to: downsampled_size
       })
       when downsampled_size > 2 do
    avg_bucket_size = max(1, (count - 2) / (downsampled_size - 2))

    sample_to_x_fun = fn sample -> sample.value_timestamp |> DateTime.to_unix(:millisecond) end
    sample_to_y_fun = fn sample -> Map.fetch!(sample, value_column) end

    xy_to_sample_fun = fn x, y -> [{:value_timestamp, x}, {:generic_key, y}] end

    ExLTTB.Stream.downsample(
      values,
      avg_bucket_size,
      sample_to_x_fun: sample_to_x_fun,
      sample_to_y_fun: sample_to_y_fun,
      xy_to_sample_fun: xy_to_sample_fun
    )
  end

  defp pack_result([] = _values, :individual, :datastream, _endpoint_row, _path, _opts),
    do: {:error, :path_not_found}

  defp pack_result(
         values,
         :individual,
         :datastream,
         endpoint_row,
         _path,
         %{format: "structured"} = opts
       ) do
    value_key = CQLUtils.type_to_db_column_name(endpoint_row.value_type) |> String.to_atom()

    values_array =
      for value <- values do
        %{^value_key => v, value_timestamp: tstamp} = value

        %{
          "timestamp" =>
            AstarteValue.to_json_friendly(
              tstamp,
              :datetime,
              keep_milliseconds: opts.keep_milliseconds
            ),
          "value" => AstarteValue.to_json_friendly(v, endpoint_row.value_type, [])
        }
      end

    {:ok,
     %InterfaceValues{
       data: values_array
     }}
  end

  defp pack_result(
         values,
         :individual,
         :datastream,
         endpoint_row,
         path,
         %{format: "table"} = opts
       ) do
    value_name =
      path
      |> String.split("/")
      |> List.last()

    value_key = CQLUtils.type_to_db_column_name(endpoint_row.value_type) |> String.to_atom()

    values_array =
      for value <- values do
        %{^value_key => v, value_timestamp: tstamp} = value

        [
          AstarteValue.to_json_friendly(tstamp, :datetime, []),
          AstarteValue.to_json_friendly(
            v,
            endpoint_row.value_type,
            keep_milliseconds: opts.keep_milliseconds
          )
        ]
      end

    {:ok,
     %InterfaceValues{
       metadata: %{
         "columns" => %{"timestamp" => 0, value_name => 1},
         "table_header" => ["timestamp", value_name]
       },
       data: values_array
     }}
  end

  defp pack_result(
         values,
         :individual,
         :datastream,
         endpoint_row,
         _path,
         %{format: "disjoint_tables"} = opts
       ) do
    value_key = CQLUtils.type_to_db_column_name(endpoint_row.value_type) |> String.to_atom()

    values_array =
      for value <- values do
        %{^value_key => v, value_timestamp: tstamp} = value

        [
          AstarteValue.to_json_friendly(v, endpoint_row.value_type, []),
          AstarteValue.to_json_friendly(
            tstamp,
            :datetime,
            keep_milliseconds: opts.keep_milliseconds
          )
        ]
      end

    {:ok,
     %InterfaceValues{
       data: %{"value" => values_array}
     }}
  end

  defp pack_result(
         values,
         :object,
         :datastream,
         column_metadata,
         %{format: "table"} = opts
       ) do
    data = object_datastream_pack(values, column_metadata, opts)

    table_header =
      case data do
        [] -> []
        [first | _] -> first |> Map.keys()
      end

    table_header_count = table_header |> Enum.count()
    columns = table_header |> Enum.zip(0..table_header_count) |> Map.new()

    values_array = data |> Enum.map(&Map.values/1)

    {:ok,
     %InterfaceValues{
       metadata: %{"columns" => columns, "table_header" => table_header},
       data: values_array
     }}
  end

  defp pack_result(
         values,
         :object,
         :datastream,
         column_metadata,
         %{format: "disjoint_tables"} = opts
       ) do
    data = object_datastream_multilist(values, column_metadata, opts)
    {timestamps, data} = data |> Map.pop!("timestamp")

    columns =
      for {column, values} <- data, into: %{} do
        values_with_timestamp =
          Enum.zip_with(values, timestamps, fn value, timestamp -> [value, timestamp] end)

        {column, values_with_timestamp}
      end

    {:ok, %InterfaceValues{data: columns}}
  end

  defp pack_result(
         values,
         :object,
         :datastream,
         column_metadata,
         %{format: "structured"} = opts
       ) do
    data = object_datastream_pack(values, column_metadata, opts)
    {:ok, %InterfaceValues{data: data}}
  end

  defp object_datastream_multilist([] = _values, _, _), do: []

  defp object_datastream_multilist(values, column_metadata, opts) do
    timestamp_column = timestamp_column(opts.explicit_timestamp)
    keep_milliseconds? = opts.keep_milliseconds

    headers = values |> hd() |> Map.keys()
    headers_without_timestamp = headers |> List.delete(timestamp_column)

    timestamp_data =
      for value <- values do
        value
        |> Map.get(timestamp_column)
        |> AstarteValue.to_json_friendly(:datetime, keep_milliseconds: keep_milliseconds?)
      end

    for header <- headers_without_timestamp, into: %{"timestamp" => timestamp_data} do
      %{pretty_name: name, value_type: type} = column_metadata |> Map.fetch!(header)

      values =
        for value <- values do
          value
          |> Map.fetch!(header)
          |> AstarteValue.to_json_friendly(type, [])
        end

      {name, values}
    end
  end

  defp object_datastream_pack(values, column_metadata, opts) do
    timestamp_column = timestamp_column(opts.explicit_timestamp)
    keep_milliseconds? = opts.keep_milliseconds

    for value <- values do
      timestamp_value =
        value
        |> Map.get(timestamp_column)
        |> AstarteValue.to_json_friendly(:datetime, keep_milliseconds: keep_milliseconds?)

      value
      |> Map.delete(timestamp_column)
      |> Map.take(column_metadata |> Map.keys())
      |> Map.new(fn {column, value} ->
        %{pretty_name: name, value_type: type} = column_metadata |> Map.fetch!(column)
        value = AstarteValue.to_json_friendly(value, type, [])

        {name, value}
      end)
      |> Map.put("timestamp", timestamp_value)
    end
  end

  defp fetch_biginteger_opts_or_default(opts) do
    allow_bigintegers = Map.get(opts, :allow_bigintegers)
    allow_safe_bigintegers = Map.get(opts, :allow_safe_bigintegers)

    cond do
      allow_bigintegers ->
        [allow_bigintegers: allow_bigintegers]

      allow_safe_bigintegers ->
        [allow_safe_bigintegers: allow_safe_bigintegers]

      # Default allow_bigintegers to true in order to not break the existing API
      true ->
        [allow_bigintegers: true]
    end
  end

  defp timestamp_column(explicit_timestamp?) do
    case explicit_timestamp? do
      nil -> :reception_timestamp
      false -> :reception_timestamp
      true -> :value_timestamp
    end
  end
end
