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
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.AppEngine.API.Device do
  @moduledoc """
  The Device context.
  """
  alias Astarte.AppEngine.API.Config
  alias Astarte.AppEngine.API.DataTransmitter
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.DeviceNotFoundError
  alias Astarte.AppEngine.API.Device.DevicesList
  alias Astarte.AppEngine.API.Device.DevicesListOptions
  alias Astarte.AppEngine.API.Device.EndpointNotFoundError
  alias Astarte.AppEngine.API.Device.InterfaceNotFoundError
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.AppEngine.API.Device.InterfaceValuesOptions
  alias Astarte.AppEngine.API.Device.PathNotFoundError
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Interface.Aggregation
  alias Astarte.Core.Interface.Type
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.ValueType
  alias Astarte.Core.StorageType
  alias CQEx.Client, as: DatabaseClient
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult
  alias Ecto.Changeset
  require Logger

  def list_devices!(realm_name, params) do
    changeset = DevicesListOptions.changeset(%DevicesListOptions{}, params)

    with {:ok, options} <- Changeset.apply_action(changeset, :insert),
         {:ok, client} <- DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]) do
      retrieve_devices_list(client, options.limit, options.details, options.from_token)
    end
  end

  @doc """
  Returns a DeviceStatus struct which represents device status.
  Device status returns information such as connected, last_connection and last_disconnection.
  """
  def get_device_status!(realm_name, encoded_device_id) do
    with {:ok, client} <- DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]) do
      device_id = decode_device_id(encoded_device_id)
      retrieve_device_status(client, device_id)
    end
  end

  def merge_device_status!(realm_name, encoded_device_id, device_status_merge) do
    device_id = decode_device_id(encoded_device_id)

    with {:ok, client} <- DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]) do
      Enum.find_value(Map.get(device_status_merge, "aliases", %{}), :ok, fn {alias_upd_key, alias_upd_value} ->
        result =
          if alias_upd_value do
            insert_alias(client, device_id, alias_upd_key, alias_upd_value)
          else
            delete_alias(client, device_id, alias_upd_key)
          end

        if match?({:error, _}, result) do
          result
        else
          nil
        end
      end)
    end
  end

  @doc """
  Returns the list of interfaces.
  """
  def list_interfaces!(realm_name, encoded_device_id) do
    client = DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

    device_id = decode_device_id(encoded_device_id)

    retrieve_interfaces_list!(client, device_id)
  end

  @doc """
  Gets all values set on a certain interface.
  This function handles all GET requests on /{realm_name}/devices/{device_id}/interfaces/{interface}
  """
  def get_interface_values!(realm_name, encoded_device_id, interface, params) do
    changeset = InterfaceValuesOptions.changeset(%InterfaceValuesOptions{}, params)

    with {:ok, options} <- Changeset.apply_action(changeset, :insert) do
      client = DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

      device_id = decode_device_id(encoded_device_id)

      major_version = interface_version!(client, device_id, interface)

      interface_row = retrieve_interface_row!(client, interface, major_version)

      do_get_interface_values!(client, device_id, Aggregation.from_int(interface_row[:flags]), interface_row, options)
    end
  end

  @doc """
  Gets a single interface_values.

  Raises if the Interface values does not exist.
  """
  def get_interface_values!(realm_name, encoded_device_id, interface, no_prefix_path, params) do
    changeset = InterfaceValuesOptions.changeset(%InterfaceValuesOptions{}, params)

    with {:ok, options} <- Changeset.apply_action(changeset, :insert) do
      client = DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

      device_id = decode_device_id(encoded_device_id)

      path = "/" <> no_prefix_path

      major_version = interface_version!(client, device_id, interface)

      interface_row = retrieve_interface_row!(client, interface, major_version)

      {status, endpoint_ids} = get_endpoint_ids(interface_row, path)
      if status == :error and endpoint_ids == :not_found do
        raise EndpointNotFoundError
      end

      endpoint_query = DatabaseQuery.new()
        |> DatabaseQuery.statement("SELECT value_type FROM endpoints WHERE interface_id=:interface_id AND endpoint_id=:endpoint_id;")
        |> DatabaseQuery.put(:interface_id, interface_row[:interface_id])

      do_get_interface_values!(client, device_id, Aggregation.from_int(interface_row[:flags]), Type.from_int(interface_row[:type]), interface_row, endpoint_ids, endpoint_query, path, options)
    end
  end

  def update_interface_values!(realm_name, encoded_device_id, interface, no_prefix_path, value, params) do
    client = DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

    device_id = decode_device_id(encoded_device_id)
    path = "/" <> no_prefix_path
    major_version = interface_version!(client, device_id, interface)
    interface_row = retrieve_interface_row!(client, interface, major_version)

    {status, endpoint_ids} = get_endpoint_ids(interface_row, path)
    if status == :error and endpoint_ids == :not_found do
      raise EndpointNotFoundError
    end

    [endpoint_id] = endpoint_ids

    timestamp =
      DateTime.utc_now()
      |> DateTime.to_unix(:milliseconds)

    interface_descriptor = InterfaceDescriptor.from_db_result!(interface_row)

    if interface_descriptor.ownership != :server do
      raise "Not Allowed"
    end

    endpoint_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT endpoint, value_type, reliabilty, retention, expiry, allow_unset, endpoint_id, interface_id FROM endpoints WHERE interface_id=:interface_id AND endpoint_id=:endpoint_id")
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)

    mapping =
      DatabaseQuery.call!(client, endpoint_query)
      |> DatabaseResult.head()
      |> Mapping.from_db_result!()

    {:ok, extended_device_id} = retrieve_extended_id(client, device_id)

    insert_value_into_db(client, interface_descriptor.storage_type, device_id, interface_descriptor, endpoint_id, mapping, path, value, timestamp)

    case interface_descriptor.type do
      :properties ->
        DataTransmitter.set_property(realm_name, extended_device_id, interface, path, value)

      :datastream ->
        DataTransmitter.push_datastream(realm_name, extended_device_id, interface, path, value)

      _ ->
        raise "Unimplemented"
    end

    {:ok, %InterfaceValues{
      data: value
    }}
  end

  defp do_get_interface_values!(client, device_id, :individual, interface_row, opts) do
    endpoint_query = DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT value_type, endpoint_id FROM endpoints WHERE interface_id=:interface_id")
      |> DatabaseQuery.put(:interface_id, interface_row[:interface_id])

    endpoint_rows =
      DatabaseQuery.call!(client, endpoint_query)

    values_map =
      Enum.reduce(endpoint_rows, %{}, fn(endpoint_row, values) ->
        #TODO: we can do this by using just one query without any filter on the endpoint
        value = retrieve_endpoint_values(client, device_id, Aggregation.from_int(interface_row[:flags]), Type.from_int(interface_row[:type]), interface_row, endpoint_row[:endpoint_id], endpoint_row, "/", opts)

        Map.merge(values, value)
      end)

    {:ok, %InterfaceValues{data: inflate_tree(values_map)}}
  end

  defp do_get_interface_values!(client, device_id, :object, interface_row, opts) do
    do_get_interface_values!(client, device_id, Aggregation.from_int(interface_row[:flags]), Type.from_int(interface_row[:type]), interface_row, nil, nil, "/", opts)
  end

  defp do_get_interface_values!(client, device_id, :individual, :properties, interface_row, endpoint_ids, endpoint_query, path, opts) do
    values_map =
      List.foldl(endpoint_ids, %{}, fn(endpoint_id, values) ->
        endpoint_query =
          endpoint_query
          |> DatabaseQuery.put(:endpoint_id, endpoint_id)

        endpoint_row =
          DatabaseQuery.call!(client, endpoint_query)
          |> DatabaseResult.head()

          #TODO: we should use path in this query if _status is :ok
          value = retrieve_endpoint_values(client, device_id, :individual, :properties, interface_row, endpoint_id, endpoint_row, path, opts)

          #TODO: next release idea: raise ValueNotSetError for debug purposes if path has not been guessed, that means it is a complete path, but it is not set.
          if value == %{} do
            raise PathNotFoundError
          end

          Map.merge(values, value)
      end)

    individual_value = Map.get(values_map, "")
    data =
      if individual_value != nil do
        individual_value
      else
        inflate_tree(values_map)
      end

    {:ok, %InterfaceValues{data: data}}
  end

  defp do_get_interface_values!(client, device_id, :individual, :datastream, interface_row, endpoint_ids, endpoint_query, path, opts) do
    [endpoint_id] = endpoint_ids

    endpoint_query =
      endpoint_query
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)

    endpoint_row =
      DatabaseQuery.call!(client, endpoint_query)
      |> DatabaseResult.head()

    retrieve_endpoint_values(client, device_id, :individual, :datastream, interface_row, endpoint_id, endpoint_row, path, opts)
  end

  defp do_get_interface_values!(client, device_id, :object, :datastream, interface_row, _endpoint_ids, _endpoint_query, path, opts) do
    endpoint_query = DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT endpoint, value_type FROM endpoints WHERE interface_id=:interface_id;")
      |> DatabaseQuery.put(:interface_id, interface_row[:interface_id])

    endpoint_rows = DatabaseQuery.call!(client, endpoint_query)

    interface_values = retrieve_endpoint_values(client, device_id, :object, :datastream, interface_row, nil, endpoint_rows, path, opts)

    if (elem(interface_values, 1).data == []) and (path != "/") do
      raise PathNotFoundError
    end

    interface_values
  end

  #TODO: optimize: do not use string replace
  defp simplify_path(base_path, path) do
    no_basepath = String.replace_prefix(path, base_path, "")

    case no_basepath do
      "/" <> noleadingslash -> noleadingslash
      already_noleadingslash -> already_noleadingslash
    end
  end

  defp inflate_tree(values_map) do
    Enum.reduce(values_map, %{}, fn({key, value}, acc) ->
      new_value =
        if String.contains?(key, "/") do
          build_tree_from_path(key, value)
        else
          %{key => value}
        end

      merge_tree(acc, new_value)
    end)
  end

  defp build_tree_from_path(path, value) do
    tokens = String.split(path, "/")

    List.foldr(tokens, value, fn(token, subtree) ->
      %{token => subtree}
    end)
  end

  defp merge_tree(existing_tree, new_tree) do
    {subkey, subtree} = Enum.at(new_tree, 0)

    cond do
      Map.get(existing_tree, subkey) == nil ->
        Map.put(existing_tree, subkey, subtree)

      is_map(subtree) ->
        Map.put(existing_tree, subkey, merge_tree(Map.get(existing_tree, subkey), subtree))

      true ->
        Map.put(existing_tree, subkey, subtree)
    end
  end

  defp get_endpoint_ids(interface_metadata, path) do
    automaton = {:erlang.binary_to_term(interface_metadata[:automaton_transitions]), :erlang.binary_to_term(interface_metadata[:automaton_accepting_states])}
    case Astarte.Core.Mapping.EndpointsAutomaton.resolve_path(path, automaton) do
      {:ok, endpoint_id} ->
        {interface_metadata, [endpoint_id]}

      {:guessed, endpoint_ids} ->
        {interface_metadata, endpoint_ids}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp retrieve_interfaces_list!(client, device_id) do
    device_introspection_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT introspection FROM devices WHERE device_id=:device_id")
      |> DatabaseQuery.put(:device_id, device_id)

    device_row =
      DatabaseQuery.call!(client, device_introspection_query)
      |> DatabaseResult.head()

    if device_row == :empty_dataset do
      raise DeviceNotFoundError
    end

    for {interface_name, _interface_major} <- device_row[:introspection] do
      interface_name
    end
  end

  defp interface_version!(client, device_id, interface) do
    device_introspection_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT introspection FROM devices WHERE device_id=:device_id")
      |> DatabaseQuery.put(:device_id, device_id)

    device_row =
      DatabaseQuery.call!(client, device_introspection_query)
      |> DatabaseResult.head()

    if device_row == :empty_dataset do
      raise DeviceNotFoundError
    end

    interface_tuple =
      device_row[:introspection]
      |> List.keyfind(interface, 0)

    case interface_tuple do
      {_interface_name, interface_major} ->
        interface_major

      nil ->
        #TODO: report device introspection here for debug purposes
        raise InterfaceNotFoundError
    end
  end

  defp retrieve_interface_row!(client, interface, major_version) do
    interface_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT name, major_version, minor_version, interface_id, type, quality, flags, storage, storage_type, automaton_transitions, automaton_accepting_states FROM interfaces" <>
                                 " WHERE name=:name AND major_version=:major_version")
      |> DatabaseQuery.put(:name, interface)
      |> DatabaseQuery.put(:major_version, major_version)

    interface_row =
      DatabaseQuery.call!(client, interface_query)
      |> DatabaseResult.head()

    if interface_row == :empty_dataset do
      Logger.warn "Device.retrieve_interface_row: interface not found. This error here means that the device has an interface that is not installed."
      raise InterfaceNotFoundError
    end

    interface_row
  end

  defp decode_device_id(encoded_device_id) do
    << device_uuid :: binary-size(16), _extended_id :: binary >> = Base.url_decode64!(encoded_device_id, padding: false)

    device_uuid
  end

  defp prepare_get_property_statement(value_type, metadata, table_name, :multi_interface_individual_properties_dbtable) do
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

  defp prepare_get_individual_datastream_statement(value_type, metadata, table_name, :multi_interface_individual_datastream_dbtable, opts) do
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

        (opts.since == nil) and (opts.since_after == nil) ->
          {"", nil}
      end

    {to_statement, to_value} =
      if opts.to != nil do
        {"AND value_timestamp < :to_timestamp", opts.to}

      else
        {"", nil}
      end

    query_limit = min(opts.limit, Config.max_results_limit())
    {limit_statement, limit_value} =
      cond do
        # Check the explicit user defined limit to know if we have to reorder data
        (opts.limit != nil) and (since_value == nil) ->
          {"ORDER BY endpoint_id DESC, path DESC, value_timestamp DESC LIMIT :limit_nrows", query_limit}

        (query_limit != nil) ->
          {"LIMIT :limit_nrows", query_limit}

        true ->
          {"", nil}
      end

    query =
      if since_statement != "" do
        %{since: DateTime.to_unix(since_value, :milliseconds)}
      else
        %{}
      end

    query =
      if to_statement != "" do
        query
        |> Map.put(:to_timestamp, DateTime.to_unix(to_value, :milliseconds))
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
      "SELECT value_timestamp, #{CQLUtils.type_to_db_column_name(value_type)} #{metadata_column} FROM #{table_name} #{where_clause}",
      "SELECT count(value_timestamp) FROM #{table_name} #{where_clause}",
      query
    }
  end

  defp column_pretty_name(endpoint) do
    [pretty_name] =
      endpoint
      |> String.split("/")
      |> tl

    pretty_name
  end

  defp retrieve_endpoint_values(_client, _device_id, :individual, :datastream, _interface_row, _endpoint_id, _endpoint_row, "/", _opts) do
    #TODO: Swagger specification says that last value for each path sould be returned, we cannot implement this right now.
    # it is required to use individual_property table to store available path, then we should iterate on all of them and report
    # most recent value.
    raise "TODO"
  end

  defp retrieve_endpoint_values(client, device_id, :object, :datastream, interface_row, _endpoint_id, endpoint_rows, "/", opts) do
    # FIXME: reading result wastes atoms: new atoms are allocated every time a new table is seen
    # See cqerl_protocol.erl:330 (binary_to_atom), strings should be used when dealing with large schemas
    {columns, column_atom_to_pretty_name, downsample_column_atom} =
      Enum.reduce(endpoint_rows, {"", %{}, nil}, fn(endpoint, {query_acc, atoms_map, prev_downsample_column_atom}) ->
        endpoint_name = endpoint[:endpoint]
        column_name = CQLUtils.endpoint_to_db_column_name(endpoint_name)

        next_query_acc = "#{query_acc} #{column_name}, "
        column_atom = String.to_atom(column_name)
        pretty_name = column_pretty_name(endpoint_name)
        next_atom_map = Map.put(atoms_map, column_atom, pretty_name)

        if (opts.downsample_key == pretty_name) do
          {next_query_acc, next_atom_map, column_atom}
        else
          {next_query_acc, next_atom_map, prev_downsample_column_atom}
        end
      end)

    {since_statement, since_value} =
      cond do
        opts.since != nil ->
          {"AND reception_timestamp >= :since", opts.since}

        opts.since_after != nil ->
          {"AND reception_timestamp > :since", opts.since_after}

        (opts.since == nil) and (opts.since_after == nil) ->
          {"", nil}
      end

    {to_statement, to_value} =
      if opts.to != nil do
        {"AND reception_timestamp < :to_timestamp", opts.to}

      else
        {"", nil}
      end

    query_limit = min(opts.limit, Config.max_results_limit())
    {limit_statement, limit_value} =
      cond do
        # Check the explicit user defined limit to know if we have to reorder data
        (opts.limit != nil) and (since_value == nil) ->
          {"ORDER BY reception_timestamp DESC LIMIT :limit_nrows", query_limit}

        (query_limit != nil) ->
          {"LIMIT :limit_nrows", query_limit}

        true ->
          {"", nil}
      end

    where_clause = "WHERE device_id=:device_id #{since_statement} #{to_statement} #{limit_statement} ;"
    values_query_statement = "SELECT #{columns} reception_timestamp FROM #{interface_row[:storage]} #{where_clause};"

    values_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(values_query_statement)
      |> DatabaseQuery.put(:device_id, device_id)

    values_query =
      if since_statement != "" do
        values_query
        |> DatabaseQuery.put(:since, DateTime.to_unix(since_value, :milliseconds))
      else
        values_query
      end

    values_query =
      if to_statement != "" do
        values_query
        |> DatabaseQuery.put(:to_timestamp, DateTime.to_unix(to_value, :milliseconds))
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

    count_query_statement = "SELECT count(reception_timestamp) FROM #{interface_row[:storage]} #{where_clause} ;"
    count_query =
      values_query
      |> DatabaseQuery.statement(count_query_statement)

    count = get_results_count(client, count_query, opts)

    values
    |> maybe_downsample_to(count, :object, %InterfaceValuesOptions{opts | downsample_key: downsample_column_atom})
    |> pack_result(:object, :datastream, column_atom_to_pretty_name, opts)
  end

  defp retrieve_endpoint_values(client, device_id, :individual, :datastream, interface_row, endpoint_id, endpoint_row, path, opts) do
    {values_query_statement, count_query_statement, q_params} =
      prepare_get_individual_datastream_statement(
        Astarte.Core.Mapping.ValueType.from_int(endpoint_row[:value_type]),
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

    values
    |> maybe_downsample_to(count, :individual, opts)
    |> pack_result(:individual, :datastream, endpoint_row, path, opts)
  end

  defp retrieve_endpoint_values(client, device_id, :individual, :properties, interface_row, endpoint_id, endpoint_row, path, opts) do
    query_statement = prepare_get_property_statement(Astarte.Core.Mapping.ValueType.from_int(endpoint_row[:value_type]), false, interface_row[:storage], StorageType.from_int(interface_row[:storage_type]))
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(query_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_row[:interface_id])
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)

    values =
      DatabaseQuery.call!(client, query)
      |> Enum.reduce(%{}, fn(row, values_map) ->
        if String.starts_with?(row[:path], path) do
          [{:path, row_path}, {_, row_value}] = row

          simplified_path = simplify_path(path, row_path)
          nice_value = db_value_to_json_friendly_value(row_value, ValueType.from_int(endpoint_row[:value_type]), allow_bigintegers: true)

          Map.put(values_map, simplified_path, nice_value)
        else
          values_map
        end
      end)

    values
  end

  defp get_results_count(_client, _count_query, %InterfaceValuesOptions{downsample_to: nil}) do
    # Count will be ignored since there's no downsample_to
    nil
  end

  defp get_results_count(client, count_query, opts) do
    with {:ok, result} <- DatabaseQuery.call(client, count_query),
         [{_count_key, count}] <- DatabaseResult.head(result) do
      min(count, opts.limit)
    else
      error ->
        Logger.warn("Can't retrieve count for #{inspect count_query}: #{inspect error}")
        nil
    end
  end

  defp maybe_downsample_to(values, _count, _aggregation, %InterfaceValuesOptions{downsample_to: nil}) do
    values
  end

  defp maybe_downsample_to(values, nil, _aggregation, _opts) do
    # TODO: we can't downsample an object without a valid count, propagate an error changeset
    # when we start using changeset consistently here
    Logger.warn("No valid count in maybe_downsample_to")
    values
  end

  defp maybe_downsample_to(values, _count, :object, %InterfaceValuesOptions{downsample_key: nil}) do
    # TODO: we can't downsample an object without downsample_key, propagate an error changeset
    # when we start using changeset consistently here
    Logger.warn("No valid downsample_key found in maybe_downsample_to")
    values
  end

  defp maybe_downsample_to(values, count, :object, %InterfaceValuesOptions{downsample_to: downsampled_size, downsample_key: downsample_key})
      when downsampled_size > 2 do
    avg_bucket_size = max(1, ((count - 2) / (downsampled_size - 2)))

    sample_to_x_fun = fn sample -> Keyword.get(sample, :reception_timestamp) end
    sample_to_y_fun = fn sample -> Keyword.get(sample, downsample_key) end
    xy_to_sample_fun = fn x, y -> [{:reception_timestamp, x}, {downsample_key, y}] end

    ExLTTB.Stream.downsample(
      values,
      avg_bucket_size,
      sample_to_x_fun: sample_to_x_fun,
      sample_to_y_fun: sample_to_y_fun,
      xy_to_sample_fun: xy_to_sample_fun
    )
  end

  defp maybe_downsample_to(values, count, :individual, %InterfaceValuesOptions{downsample_to: downsampled_size}) when downsampled_size > 2 do
    avg_bucket_size = max(1, ((count - 2) / (downsampled_size - 2)))

    sample_to_x_fun = fn sample -> Keyword.get(sample, :value_timestamp) end
    sample_to_y_fun = fn [{:value_timestamp, _timestamp}, {_key, value}] -> value end
    xy_to_sample_fun = fn x, y -> [{:value_timestamp, x}, {:generic_key, y}] end

    ExLTTB.Stream.downsample(
      values,
      avg_bucket_size,
      sample_to_x_fun: sample_to_x_fun,
      sample_to_y_fun: sample_to_y_fun,
      xy_to_sample_fun: xy_to_sample_fun
    )
  end

  defp pack_result(values, :individual, :datastream, endpoint_row, _path, %{format: "structured"} = opts) do
    values_array =
      for value <- values do
        [{:value_timestamp, tstamp}, {_, v}] = value
        %{"timestamp" => db_value_to_json_friendly_value(tstamp, :datetime, keep_milliseconds: opts.keep_milliseconds), "value" => db_value_to_json_friendly_value(v, ValueType.from_int(endpoint_row[:value_type]), [])}
      end

    if values_array == [] do
      raise PathNotFoundError
    end

    {:ok, %InterfaceValues{
      data: values_array
    }}
  end

  defp pack_result(values, :individual, :datastream, endpoint_row, path, %{format: "table"} = opts) do
    value_name =
      path
      |> String.split("/")
      |> List.last

    values_array =
      for value <- values do
        [{:value_timestamp, tstamp}, {_, v}] = value
        [db_value_to_json_friendly_value(tstamp, :datetime, []), db_value_to_json_friendly_value(v, ValueType.from_int(endpoint_row[:value_type]), keep_milliseconds: opts.keep_milliseconds)]
      end

    if values_array == [] do
      raise PathNotFoundError
    end

    {:ok, %InterfaceValues{
      metadata: %{"columns" => %{"timestamp" => 0, value_name => 1}, "table_header" => ["timestamp", value_name]},
      data: values_array
    }}
  end

  defp pack_result(values, :individual, :datastream, endpoint_row, _path, %{format: "disjoint_tables"} = opts) do
    values_array =
      for value <- values do
        [{:value_timestamp, tstamp}, {_, v}] = value
        [db_value_to_json_friendly_value(v, ValueType.from_int(endpoint_row[:value_type]), []), db_value_to_json_friendly_value(tstamp, :datetime, keep_milliseconds: opts.keep_milliseconds)]
      end

    if values_array == [] do
      raise PathNotFoundError
    end

    {:ok, %InterfaceValues{
      data: %{"value" => values_array}
    }}
  end

  defp pack_result(values, :object, :datastream, column_atom_to_pretty_name, %{format: "table"} = opts) do
    {_cols_count, columns, reverse_table_header} =
      List.foldl(DatabaseResult.head(values), {1, %{"timestamp" => 0}, ["timestamp"]}, fn({column, _column_value}, {next_index, acc, list_acc}) ->
        pretty_name = column_atom_to_pretty_name[column]
        if (pretty_name != nil) and (pretty_name != "timestamp") do
          {next_index + 1, Map.put(acc, pretty_name, next_index), [pretty_name | list_acc]}
        else
          {next_index, acc, list_acc}
        end
      end)
    table_header = Enum.reverse(reverse_table_header)

    values_array =
      for value <- values do
        base_array_entry = [db_value_to_json_friendly_value(value[:reception_timestamp], :datetime, keep_milliseconds: opts.keep_milliseconds)]

        List.foldl(value, base_array_entry, fn({column, column_value}, acc) ->
          pretty_name = column_atom_to_pretty_name[column]
          if pretty_name do
            [column_value | acc]
          else
            acc
          end
        end)
        |> Enum.reverse()
      end

    {:ok, %InterfaceValues{
      metadata: %{"columns" => columns, "table_header" => table_header},
      data: values_array
    }}
  end

  defp pack_result(values, :object, :datastream, column_atom_to_pretty_name, %{format: "disjoint_tables"} = opts) do
    reversed_columns_map =
      Enum.reduce(values, %{}, fn(value, columns_acc) ->
        List.foldl(value, columns_acc, fn({column, column_value}, acc) ->
          pretty_name = column_atom_to_pretty_name[column]
          if pretty_name do
            column_list = [[column_value, db_value_to_json_friendly_value(value[:reception_timestamp], :datetime, keep_milliseconds: opts.keep_milliseconds)] | Map.get(columns_acc, pretty_name, [])]
            Map.put(acc, pretty_name, column_list)
          else
            acc
          end
        end)
      end)

    columns =
      Enum.reduce(reversed_columns_map, %{}, fn({column_name, column_values}, acc) ->
        Map.put(acc, column_name, Enum.reverse(column_values))
      end)

    {:ok, %InterfaceValues{
      data: columns
    }}
  end

  defp pack_result(values, :object, :datastream, column_atom_to_pretty_name, %{format: "structured"} = opts) do
    values_list =
      for value <- values do
        base_array_entry = %{"timestamp" => db_value_to_json_friendly_value(value[:reception_timestamp], :datetime, keep_milliseconds: opts.keep_milliseconds)}

        List.foldl(value, base_array_entry, fn({column, column_value}, acc) ->
          pretty_name = column_atom_to_pretty_name[column]
          if pretty_name do
            Map.put(acc, pretty_name, column_value)
          else
            acc
          end
        end)
      end

    {:ok, %InterfaceValues{data: values_list}}
  end

  @device_status_columns_without_device_id """
    , aliases
    , connected
    , last_connection
    , last_disconnection
    , first_pairing
    , last_pairing_ip
    , last_seen_ip
    , total_received_msgs
    , total_received_bytes
  """

  defp device_status_row_to_device_status(row) do
    [
      device_id: device_id,
      aliases: aliases,
      connected: connected,
      last_connection: last_connection,
      last_disconnection: last_disconnection,
      first_pairing: first_pairing,
      last_pairing_ip: last_pairing_ip,
      last_seen_ip: last_seen_ip,
      total_received_msgs:  total_received_msgs,
      total_received_bytes: total_received_bytes
    ] = row

    %DeviceStatus{
      id: Base.url_encode64(device_id, padding: false),
      aliases: Enum.into(aliases || [], %{}),
      connected: connected,
      last_connection: millis_or_null_to_datetime!(last_connection),
      last_disconnection: millis_or_null_to_datetime!(last_disconnection),
      first_pairing: millis_or_null_to_datetime!(first_pairing),
      last_pairing_ip: ip_or_null_to_string(last_pairing_ip),
      last_seen_ip: ip_or_null_to_string(last_seen_ip),
      total_received_msgs: total_received_msgs,
      total_received_bytes: total_received_bytes
    }
  end

  # TODO: move to a different context?
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
            -9223372036854775808

        first ->
            first + 1
      end

    devices_list_statement =
      """
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

  # TODO: move to a different context?
  defp retrieve_devices_list(client, limit, retrieve_details, previous_token) do
    with {:ok, result} <- execute_devices_list_query(client, limit, retrieve_details, previous_token) do
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
      not_ok ->
        Logger.warn("Device.retrieve_devices_list: database error: #{inspect(not_ok)}")
        {:error, :database_error}
    end
  end

  defp retrieve_device_status(client, device_id) do
    device_statement =
      """
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

      not_ok ->
        Logger.warn("Device.retrieve_device_status: database error: #{inspect(not_ok)}")
        {:error, :database_error}
    end
  end

  def retrieve_extended_id(client, device_id) do
    extended_id_statement = "SELECT extended_id FROM devices WHERE device_id=:device_id"

    extended_id_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(extended_id_statement)
      |> DatabaseQuery.put(:device_id, device_id)

    with {:ok, result} <- DatabaseQuery.call(client, extended_id_query),
         [extended_id: extended_id] <- DatabaseResult.head(result) do
      {:ok, extended_id}
    else
       :empty_dataset ->
        {:error, :device_not_found}

      not_ok ->
        Logger.warn("Device.retrieve_extended_id: database error: #{inspect(not_ok)}")
        {:error, :database_error}
    end
  end

  defp delete_alias(client, device_id, alias_tag) do
    retrieve_aliases_statement = "SELECT aliases FROM devices WHERE device_id = :device_id;"

    retrieve_aliases_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(retrieve_aliases_statement)
      |> DatabaseQuery.put(:device_id, device_id)

    with {:ok, result} <- DatabaseQuery.call(client, retrieve_aliases_query),
         [aliases: aliases] <- DatabaseResult.head(result),
         {^alias_tag, alias_value} <- Enum.find(aliases || [], fn a -> match?({^alias_tag, _}, a) end) do

      # TODO: Add IF EXISTS and batch
      delete_alias_from_device_statement = "DELETE aliases[:alias_tag] FROM devices WHERE device_id = :device_id;"

      delete_alias_from_device_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(delete_alias_from_device_statement)
        |> DatabaseQuery.put(:alias_tag, alias_tag)
        |> DatabaseQuery.put(:device_id, device_id)

      delete_alias_from_names_statement = "DELETE FROM names WHERE object_name = :alias AND object_type = 1;"

      delete_alias_from_names_query =
        DatabaseQuery.new()
        |> DatabaseQuery.statement(delete_alias_from_names_statement)
        |> DatabaseQuery.put(:alias, alias_value)
        |> DatabaseQuery.put(:device_id, device_id)

      with {:ok, _result} <- DatabaseQuery.call(client, delete_alias_from_device_query),
           {:ok, _result} <- DatabaseQuery.call(client, delete_alias_from_names_query) do
        :ok
      else
        not_ok ->
          Logger.warn("Device.delete_alias: database error: #{inspect(not_ok)}")
          {:error, :database_error}
      end
    else
      :empty_dataset ->
        {:error, :device_not_found}

      nil ->
        {:error, :alias_tag_not_found}

      not_ok ->
        Logger.warn("Device.delete_alias: database error: #{inspect(not_ok)}")
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

  defp insert_alias(client, device_id, alias_tag, alias_value) do
    # TODO: Add  IF NOT EXISTS and batch queries together
    insert_alias_to_names_statement =
      "INSERT INTO names (object_name, object_type, object_uuid) VALUES (:alias, 1, :device_id);"

    insert_alias_to_names_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_alias_to_names_statement)
      |> DatabaseQuery.put(:alias, alias_value)
      |> DatabaseQuery.put(:device_id, device_id)

    insert_alias_to_device_statement = "UPDATE devices SET aliases[:alias_tag] = :alias WHERE device_id = :device_id;"

    insert_alias_to_device_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(insert_alias_to_device_statement)
      |> DatabaseQuery.put(:alias_tag, alias_tag)
      |> DatabaseQuery.put(:alias, alias_value)
      |> DatabaseQuery.put(:device_id, device_id)

    # TODO: avoid to delete and insert again the same alias if it didn't change
    with :ok <- try_delete_alias(client, device_id, alias_tag),
         {:ok, _result} <- DatabaseQuery.call(client, insert_alias_to_names_query),
         {:ok, _result} <- DatabaseQuery.call(client, insert_alias_to_device_query) do
      :ok
    else
      {:error, :device_not_found} ->
        {:error, :device_not_found}

      not_ok ->
        Logger.warn("Device.insert_alias: database error: #{inspect(not_ok)}")
        {:error, :database_error}
    end
  end

  def device_alias_to_device_id(client, device_alias) do
    device_id_statement = "SELECT object_uuid FROM names WHERE object_name = :device_alias AND object_type = 1;"

    device_id_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(device_id_statement)
      |> DatabaseQuery.put(:device_alias, device_alias)

    with {:ok, result} <- DatabaseQuery.call(client, device_id_query),
         [object_uuid: device_id] <- DatabaseResult.head(result) do
      {:ok, device_id}
    else
      :empty_dataset ->
        {:error, :device_not_found}

      not_ok ->
        Logger.warn("Device.device_alias_to_device_id: database error: #{inspect(not_ok)}")
        {:error, :database_error}
    end
  end

  #TODO Copy&pasted from data updater plant, make it a library
  defp insert_value_into_db(db_client, :multi_interface_individual_properties_dbtable, device_id, interface_descriptor, endpoint_id, endpoint, path, value, timestamp) do
    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("INSERT INTO #{interface_descriptor.storage} " <>
          "(device_id, interface_id, endpoint_id, path, reception_timestamp, #{CQLUtils.type_to_db_column_name(endpoint.value_type)}) " <>
          "VALUES (:device_id, :interface_id, :endpoint_id, :path, :reception_timestamp, :value);")
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.put(:reception_timestamp, timestamp)
      |> DatabaseQuery.put(:reception_timestamp_submillis, 0)
      |> DatabaseQuery.put(:value, to_db_friendly_type(value))

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  #TODO Copy&pasted from data updater plant, make it a library
  defp insert_value_into_db(db_client, :multi_interface_individual_datastream_dbtable, device_id, interface_descriptor, endpoint_id, endpoint, path, value, timestamp) do
    # TODO: use received value_timestamp when needed
    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("INSERT INTO #{interface_descriptor.storage} " <>
          "(device_id, interface_id, endpoint_id, path, value_timestamp, reception_timestamp, reception_timestamp_submillis, #{CQLUtils.type_to_db_column_name(endpoint.value_type)}) " <>
          "VALUES (:device_id, :interface_id, :endpoint_id, :path, :value_timestamp, :reception_timestamp, :reception_timestamp_submillis, :value);")
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.put(:value_timestamp, timestamp)
      |> DatabaseQuery.put(:reception_timestamp, timestamp)
      |> DatabaseQuery.put(:reception_timestamp_submillis, 0)
      |> DatabaseQuery.put(:value, to_db_friendly_type(value))

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  #TODO Copy&pasted from data updater plant, make it a library
  defp to_db_friendly_type(value) do
    value
  end

  defp db_value_to_json_friendly_value(value, :longinteger, opts) do
    cond do
      opts[:allow_bigintegers] ->
        value

      opts[:allow_safe_bigintegers] ->
        # the following magic value is the biggest mantissa allowed in a double value
        if value <= 0xFFFFFFFFFFFFF do
          value
        else
          Integer.to_string(value)
        end

      true ->
        Integer.to_string(value)
    end
  end

  defp db_value_to_json_friendly_value(value, :binaryblob, _opts) do
    Base.encode64(value)
  end

  defp db_value_to_json_friendly_value(value, :datetime, opts) do
    if opts[:keep_milliseconds] do
      value
    else
      DateTime.from_unix!(value, :millisecond)
    end
  end

  defp db_value_to_json_friendly_value(value, :longintegerarray, opts) do
    for item <- value do
      db_value_to_json_friendly_value(item, :longintegerarray, opts)
    end
  end

  defp db_value_to_json_friendly_value(value, :binaryblobarray, _opts) do
    for item <- value do
      Base.encode64(item)
    end
  end

  defp db_value_to_json_friendly_value(value, :datetimearray, opts) do
    for item <- value do
      db_value_to_json_friendly_value(item, :datetimearray, opts)
    end
  end

  defp db_value_to_json_friendly_value(:null, _value_type, _opts) do
    Logger.warn "Device.db_value_to_json_friendly_value: it has been found a path with a :null value. This shouldn't happen."
    raise PathNotFoundError
  end

  defp db_value_to_json_friendly_value(value, _value_type, _opts) do
    value
  end

  defp millis_or_null_to_datetime!(nil) do
    nil
  end

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
end
