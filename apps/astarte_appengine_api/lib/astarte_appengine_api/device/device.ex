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
  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.DeviceNotFoundError
  alias Astarte.AppEngine.API.Device.DevicesListingNotAllowedError
  alias Astarte.AppEngine.API.Device.EndpointNotFoundError
  alias Astarte.AppEngine.API.Device.InterfaceNotFoundError
  alias Astarte.AppEngine.API.Device.PathNotFoundError
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Interface.Aggregation
  alias Astarte.Core.Interface.Type
  alias Astarte.Core.Mapping.ValueType
  alias CQEx.Client, as: DatabaseClient
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult
  require Logger

  @doc """
  Intentionally not implemented.
  """
  def list_devices!(_realm_name) do
    #TODO: It should list available devices, but it doesn't scale well. It must be implemented in a meaningful way.
    # Possible implementations: raise Forbidden, show some stats, list all devices only if configured on small installations.
    raise DevicesListingNotAllowedError
  end

  @doc """
  Returns a DeviceStatus struct which represents device status.
  Device status returns information such as connected, last_connection and last_disconnection.
  """
  def get_device_status!(realm_name, encoded_device_id) do
    client = DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

    device_id = decode_device_id(encoded_device_id)

    device_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT extended_id, connected, last_connection, last_disconnection, first_pairing, last_seen_ip, last_pairing_ip, total_received_msgs, total_received_bytes FROM devices WHERE device_id=:device_id")
      |> DatabaseQuery.put(:device_id, device_id)

    device_row =
      DatabaseQuery.call!(client, device_query)
      |> DatabaseResult.head()

    %DeviceStatus{
      id: device_row[:extended_id],
      connected: device_row[:connected],
      last_connection: millis_or_null_to_datetime!(device_row[:last_connection]),
      last_disconnection: millis_or_null_to_datetime!(device_row[:last_disconnection]),
      first_pairing: millis_or_null_to_datetime!(device_row[:first_pairing]),
      last_pairing_ip: ip_or_null_to_string(device_row[:last_pairing_ip]),
      last_seen_ip: ip_or_null_to_string(device_row[:last_seen_ip]),
      total_received_msgs: device_row[:total_received_msgs],
      total_received_bytes: device_row[:total_received_bytes]
    }
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
  def get_interface_values!(realm_name, encoded_device_id, interface) do
    client = DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

    device_id = decode_device_id(encoded_device_id)

    major_version = interface_version!(client, device_id, interface)

    interface_row = retrieve_interface_row!(client, interface, major_version)

    endpoint_query = DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT value_type, endpoint_id FROM endpoints WHERE interface_id=:interface_id")
      |> DatabaseQuery.put(:interface_id, interface_row[:interface_id])

    endpoint_rows =
      DatabaseQuery.call!(client, endpoint_query)

    values_map =
      Enum.reduce(endpoint_rows, %{}, fn(endpoint_row, values) ->
        #TODO: we can do this by using just one query without any filter on the endpoint
        value = retrieve_endpoint_values(client, device_id, Aggregation.from_int(interface_row[:flags]), Type.from_int(interface_row[:type]), interface_row, endpoint_row[:endpoint_id], endpoint_row, "/")

        Map.merge(values, value)
      end)

    inflate_tree(values_map)
  end

  @doc """
  Gets a single interface_values.

  Raises if the Interface values does not exist.
  """
  def get_interface_values!(realm_name, encoded_device_id, interface, no_prefix_path) do
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

    do_get_interface_values!(client, device_id, Aggregation.from_int(interface_row[:flags]), Type.from_int(interface_row[:type]), interface_row, endpoint_ids, endpoint_query, path)
  end

  defp do_get_interface_values!(client, device_id, :individual, :properties, interface_row, endpoint_ids, endpoint_query, path) do
    values_map =
      List.foldl(endpoint_ids, %{}, fn(endpoint_id, values) ->
        endpoint_query =
          endpoint_query
          |> DatabaseQuery.put(:endpoint_id, endpoint_id)

        endpoint_row =
          DatabaseQuery.call!(client, endpoint_query)
          |> DatabaseResult.head()

          #TODO: we should use path in this query if _status is :ok
          value = retrieve_endpoint_values(client, device_id, :individual, :properties, interface_row, endpoint_id, endpoint_row, path)

          #TODO: next release idea: raise ValueNotSetError for debug purposes if path has not been guessed, that means it is a complete path, but it is not set.
          if value == %{} do
            raise PathNotFoundError
          end

          Map.merge(values, value)
      end)

    individual_value = Map.get(values_map, "")
    if individual_value != nil do
      individual_value
    else
      inflate_tree(values_map)
    end
  end

  defp do_get_interface_values!(client, device_id, :individual, :datastream, interface_row, endpoint_ids, endpoint_query, path) do
    [endpoint_id] = endpoint_ids

    endpoint_query =
      endpoint_query
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)

    endpoint_row =
      DatabaseQuery.call!(client, endpoint_query)
      |> DatabaseResult.head()


    values = retrieve_endpoint_values(client, device_id, :individual, :datastream, interface_row, endpoint_id, endpoint_row, path)

    if values == [] do
      raise PathNotFoundError
    end

    values
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

    #TODO: optimize schema here
    for interface_tuple <- device_row[:introspection] do
      interface_tuple
      |> String.split(";")
      |> hd
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

    interface_pair =
      device_row[:introspection]
      |> Enum.find(fn(item) -> match?([^interface, _version], String.split(item, ";")) end)

    if interface_pair == nil do
      #TODO: report device introspection here for debug purposes
      raise InterfaceNotFoundError
    end

    {major, ""} =
      interface_pair
      |> String.split(";")
      |> List.last()
      |> Integer.parse()

    major
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

  defp prepare_get_property_statement(value_type, metadata, table_name) do
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

  defp prepare_get_individual_datastream_statement(value_type, metadata, table_name, timestamp_column, opts) do
    metadata_column =
      if metadata do
        ",metadata"
      else
        ""
      end

    since =
      cond do
        (opts[:since] == true) and (opts[:since_after] == nil) ->
          "AND #{timestamp_column} >= :since"

        (opts[:since_after] == true) and (opts[:since] == nil) ->
          "AND #{timestamp_column} > :since"

        (opts[:since_after] == nil) and (opts[:since] == nil) ->
          ""
      end

    to = ""
    limit = ""

    "SELECT #{timestamp_column}, #{CQLUtils.type_to_db_column_name(value_type)} #{metadata_column} FROM #{table_name} " <>
      " WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id AND path=:path #{since} #{to} #{limit}"
  end

  defp retrieve_endpoint_values(_client, _device_id, :individual, :datastream, _interface_row, _endpoint_id, _endpoint_row, "/") do
    #TODO: Swagger specification says that last value for each path sould be returned, we cannot implement this right now.
    # it is required to use individual_property table to store available path, then we should iterate on all of them and report
    # most recent value.
    raise "TODO"
  end

  defp retrieve_endpoint_values(client, device_id, :individual, :datastream, interface_row, endpoint_id, endpoint_row, path) do
    query_statement = prepare_get_individual_datastream_statement(Astarte.Core.Mapping.ValueType.from_int(endpoint_row[:value_type]), false, interface_row[:storage], "reception_timestamp", since: true)
    query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement(query_statement)
      |> DatabaseQuery.put(:device_id, device_id)
      |> DatabaseQuery.put(:interface_id, interface_row[:interface_id])
      |> DatabaseQuery.put(:endpoint_id, endpoint_id)
      |> DatabaseQuery.put(:path, path)
      |> DatabaseQuery.put(:since, 0)

    values = DatabaseQuery.call!(client, query)

    for value <- values do
      [{:reception_timestamp, tstamp}, {_, v}] = value
      %{"timestamp" => db_value_to_json_friendly_value(tstamp, :datetime, []), "value" => db_value_to_json_friendly_value(v, ValueType.from_int(endpoint_row[:value_type]), [])}
    end
  end

  defp retrieve_endpoint_values(client, device_id, :individual, :properties, interface_row, endpoint_id, endpoint_row, path) do
    query_statement = prepare_get_property_statement(Astarte.Core.Mapping.ValueType.from_int(endpoint_row[:value_type]), false, interface_row[:storage])
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

  defp millis_or_null_to_datetime!(millis) do
    if millis == :null do
      nil
    else
      DateTime.from_unix!(millis, :millisecond)
    end
  end

  defp ip_or_null_to_string(ip) do
    if ip == :null do
      nil
    else
      ip
      |> :inet_parse.ntoa
      |> to_string
    end
  end

end
