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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Impl do
  use GenServer
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias CQEx.Client, as: DatabaseClient
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult
  require Logger

  def init_state(realm, device_id) do
    new_state = %State{
      realm: realm,
      device_id: device_id
    }

    db_client = connect_to_db(new_state)

    device_row_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT total_received_msgs, total_received_bytes, introspection FROM devices WHERE device_id=:device_id")
      |> DatabaseQuery.put(:device_id, device_id)

    device_row =
      DatabaseQuery.call!(db_client, device_row_query)
      |> DatabaseResult.head()

    %{new_state |
      connected: true,
      total_received_msgs: device_row[:total_received_msgs],
      total_received_bytes: device_row[:total_received_bytes],
      introspection: device_row[:introspection],
      interfaces: %{},
      mappings: %{}
    }
  end

  def handle_connection(state, ip_address, _delivery_tag, timestamp) do
    db_client = connect_to_db(state)

    device_update_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("UPDATE devices SET connected=true, last_connection=:last_connection, last_seen_ip=:last_seen_ip WHERE device_id=:device_id")
      |> DatabaseQuery.put(:device_id, state.device_id)
      |> DatabaseQuery.put(:last_connection, timestamp)
      |> DatabaseQuery.put(:last_seen_ip, ip_address)

    DatabaseQuery.call!(db_client, device_update_query)

    state
  end

  def handle_disconnection(state, _delivery_tag, timestamp) do
    db_client = connect_to_db(state)

    device_update_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("UPDATE devices SET connected=false, last_disconnection=:last_disconnection, " <>
        "total_received_msgs=:total_received_msgs, total_received_bytes=:total_received_bytes " <>
        "WHERE device_id=:device_id")
      |> DatabaseQuery.put(:device_id, state.device_id)
      |> DatabaseQuery.put(:last_disconnection, timestamp)
      |> DatabaseQuery.put(:total_received_msgs, state.total_received_msgs)
      |> DatabaseQuery.put(:total_received_bytes, state.total_received_bytes)

    DatabaseQuery.call!(db_client, device_update_query)

    %{state |
      connected: false
    }
  end

  def handle_data(state, interface, path, payload, _delivery_tag, timestamp) do
    db_client = connect_to_db(state)

    {interface_descriptor, new_state} = maybe_handle_cache_miss(Map.get(state.interfaces, interface), interface, state, db_client)

    {resolve_result, endpoint_id} = EndpointsAutomaton.resolve_path(path, interface_descriptor.automaton)
    endpoint = Map.get(new_state.mappings, endpoint_id)

    #TODO: use different BSON library
    value =
      case Bson.decode(payload) do
        %{v: bson_value} -> bson_value
        _ -> :error
      end

    result =
      cond do
        interface_descriptor.ownership == :server ->
          Logger.warn "#{state.realm}: Device #{inspect state.device_id} tried to write on server owned interface: #{interface}."
          {:error, :maybe_outdate_introspection}

        resolve_result != :ok ->
          Logger.warn "#{state.realm}: Cannot resolve #{path} to #{interface} endpoint."
          {:error, :maybe_outdate_introspection}

        value == :error ->
          Logger.warn "#{state.realm}: Invalid BSON payload: #{Bson.decode(payload)} sent to #{interface}#{path}."
          {:error, :invalid_message}

        true ->
          insert_value_into_db(db_client, interface_descriptor.aggregation, interface_descriptor.type, state.device_id, interface_descriptor, endpoint_id, endpoint, path, value, timestamp)
      end

    if result != :ok do
      Logger.debug "result is #{inspect result} further actions should be required."
    end

    %{new_state |
      total_received_msgs: new_state.total_received_msgs + 1,
      total_received_bytes: new_state.total_received_bytes + byte_size(payload) + byte_size(interface) + byte_size(path)
    }
  end

  def handle_introspection(state, payload, _delivery_tag, _timestamp) do
    db_client = connect_to_db(state)

    new_introspection_list =
      payload
      |> String.split(";")
      |> Enum.sort()

    #TODO: change me
    db_introspection_list =
      for introspection_item <- new_introspection_list do
        [interface_name, major_version, _minor_version] = String.split(introspection_item, ":")
        "#{interface_name};#{major_version}"
      end

    diff = List.myers_difference(Enum.sort(state.introspection), db_introspection_list)

    #TODO: handle changes
    IO.puts "Introspection changes #{inspect diff}"

    device_update_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("UPDATE devices SET introspection=:introspection WHERE device_id=:device_id")
      |> DatabaseQuery.put(:device_id, state.device_id)
      |> DatabaseQuery.put(:introspection, db_introspection_list)

    DatabaseQuery.call!(db_client, device_update_query)

    %{state |
      introspection: db_introspection_list,
      total_received_msgs: state.total_received_msgs + 1,
      total_received_bytes: state.total_received_bytes + byte_size(payload)
    }
  end

  def handle_control(state, payload, path, _delivery_tag, _timestamp) do
    IO.puts "Control on #{path}, payload: #{inspect payload}"

    state
  end

  defp maybe_handle_cache_miss(nil, interface_name, state, db_client) do
    major_version = interface_version!(db_client, state.device_id, interface_name)
    interface_row = retrieve_interface_row!(db_client, interface_name, major_version)

    interface_descriptor = InterfaceDescriptor.from_db_result!(interface_row)

    endpoint_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT endpoint, value_type, reliabilty, retention, expiry, allow_unset, endpoint_id FROM endpoints WHERE interface_id=:interface_id")
      |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)

    mappings =
      DatabaseQuery.call!(db_client, endpoint_query)
      |> Enum.reduce(state.mappings, fn(endpoint_row, acc) ->
        mapping = Mapping.from_db_result!(endpoint_row)
        Map.put(acc, mapping.endpoint_id, mapping)
      end)

    new_state = %State{state |
      interfaces: Map.put(state.interfaces, interface_name, interface_descriptor),
      mappings: mappings
    }

    {interface_descriptor, new_state}
  end

  defp maybe_handle_cache_miss(interface_descriptor, _interface_name, state, _db_client) do
    {interface_descriptor, state}
  end

  #TODO: we should pattern match on storage type instead of :individual, :property
  defp insert_value_into_db(db_client, :individual, :properties, device_id, interface_descriptor, endpoint_id, endpoint, path, value, timestamp) do
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
        |> DatabaseQuery.put(:value, value)

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  #TODO: we should pattern match on storage type instead of :individual, :datastream
  defp insert_value_into_db(db_client, :individual, :datastream, device_id, interface_descriptor, endpoint_id, endpoint, path, value, timestamp) do
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
        |> DatabaseQuery.put(:value, value)

    DatabaseQuery.call!(db_client, insert_query)

    :ok
  end

  #TODO: copied from AppEngine, make it an api
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

    #if interface_row == :empty_dataset do
    #  Logger.warn "Device.retrieve_interface_row: interface not found. This error here means that the device has an interface that is not installed."
    #  raise InterfaceNotFoundError
    #end

    interface_row
  end

  #TODO: copied from AppEngine, make it an api
  defp interface_version!(client, device_id, interface) do
    device_introspection_query =
      DatabaseQuery.new()
      |> DatabaseQuery.statement("SELECT introspection FROM devices WHERE device_id=:device_id")
      |> DatabaseQuery.put(:device_id, device_id)

    device_row =
      DatabaseQuery.call!(client, device_introspection_query)
      |> DatabaseResult.head()

    #if device_row == :empty_dataset do
    #  raise DeviceNotFoundError
    #end

    interface_pair =
      device_row[:introspection]
      |> Enum.find(fn(item) -> match?([^interface, _version], String.split(item, ";")) end)

    #if interface_pair == nil do
    #  #TODO: report device introspection here for debug purposes
    #  raise InterfaceNotFoundError
    #end

    {major, ""} =
      interface_pair
      |> String.split(";")
      |> List.last()
      |> Integer.parse()

    major
  end

  defp connect_to_db(state) do
    DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: state.realm])
  end

end
