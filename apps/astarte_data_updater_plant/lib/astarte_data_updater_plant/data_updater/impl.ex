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
  alias Astarte.Core.Triggers.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils, as: SimpleTriggersProtobufUtils
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.TriggersHandler
  alias Astarte.DataUpdaterPlant.ValueMatchOperators
  alias CQEx.Client, as: DatabaseClient
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult
  require Logger

  @max_uncompressed_payload_size 10_485_760
  @interface_lifespan_decimicroseconds 60 * 10 * 1000 * 10000
  @device_triggers_lifespan_decimicroseconds 60 * 10 * 1000 * 10000

  def init_state(realm, device_id) do
    new_state = %State{
      realm: realm,
      device_id: device_id,
      connected: true,
      interfaces: %{},
      interface_ids_to_name: %{},
      interfaces_by_expiry: [],
      mappings: %{},
      device_triggers: %{},
      data_triggers: %{},
      volatile_triggers: [],
      introspection_triggers: %{},
      last_seen_message: 0,
      last_device_triggers_refresh: 0
    }

    stats_and_introspection =
      Queries.connect_to_db(new_state)
      |> Queries.retrieve_device_stats_and_introspection!(device_id)

    Map.merge(new_state, stats_and_introspection)
  end

  def handle_connection(state, ip_address_string, delivery_tag, timestamp) do
    db_client = Queries.connect_to_db(state)

    new_state = execute_time_based_actions(state, timestamp, db_client)

    ip_address_result =
      ip_address_string
      |> to_charlist()
      |> :inet.parse_address()

    ip_address =
      case ip_address_result do
        {:ok, ip_address} ->
          ip_address

        _ ->
          Logger.warn(
            "#{new_state.realm}: Device #{pretty_device_id(new_state.device_id)}: received invalid IP address #{
              ip_address_string
            }."
          )

          {0, 0, 0, 0}
      end

    Queries.set_device_connected!(
      db_client,
      new_state.device_id,
      div(timestamp, 10000),
      ip_address
    )

    trigger_targets = Map.get(new_state.device_triggers, :on_device_connection, [])
    device_id_string = pretty_device_id(new_state.device_id)

    TriggersHandler.device_connected(
      trigger_targets,
      new_state.realm,
      device_id_string,
      ip_address_string
    )

    %{new_state | connected: true, last_seen_message: timestamp}
  end

  def handle_disconnection(state, delivery_tag, timestamp) do
    db_client = Queries.connect_to_db(state)

    new_state = execute_time_based_actions(state, timestamp, db_client)

    Queries.set_device_disconnected!(
      db_client,
      new_state.device_id,
      div(timestamp, 10000),
      new_state.total_received_msgs,
      new_state.total_received_bytes
    )

    trigger_targets = Map.get(new_state.device_triggers, :on_device_disconnection, [])
    device_id_string = pretty_device_id(new_state.device_id)
    TriggersHandler.device_disconnected(trigger_targets, new_state.realm, device_id_string)

    %{new_state | connected: false, last_seen_message: timestamp}
  end

  def handle_data(state, interface, path, payload, delivery_tag, timestamp) do
    db_client = Queries.connect_to_db(state)

    new_state = execute_time_based_actions(state, timestamp, db_client)

    {interface_descriptor, new_state} =
      maybe_handle_cache_miss(
        Map.get(new_state.interfaces, interface),
        interface,
        new_state,
        db_client
      )

    {resolve_result, endpoint} =
      case interface_descriptor.aggregation do
        :individual ->
          {resolve_result, endpoint_id} =
            EndpointsAutomaton.resolve_path(path, interface_descriptor.automaton)

          endpoint = Map.get(new_state.mappings, endpoint_id)

          {resolve_result, endpoint}

        :object ->
          {:ok, %Mapping{}}
      end

    {value, value_timestamp, metadata} = PayloadsDecoder.decode_bson_payload(payload, timestamp)

    # TODO: here we need to set value_timestamp to reception_timestamp if custom timestamp
    # is not allowed

    result =
      cond do
        interface_descriptor.ownership == :server ->
          Logger.warn(
            "#{new_state.realm}: Device #{pretty_device_id(new_state.device_id)} tried to write on server owned interface: #{
              interface
            }."
          )

          {:error, :maybe_outdated_introspection}

        resolve_result != :ok ->
          Logger.warn("#{new_state.realm}: Cannot resolve #{path} to #{interface} endpoint.")
          {:error, :maybe_outdated_introspection}

        value == :error ->
          Logger.warn(
            "#{new_state.realm}: Invalid BSON payload: #{inspect(payload)} sent to #{interface}#{
              path
            }."
          )

          {:error, :invalid_message}

        true ->
          realm = new_state.realm
          device_id_string = pretty_device_id(new_state.device_id)
          interface_name = interface_descriptor.name

          any_interface_triggers =
            get_on_data_triggers(new_state, :on_incoming_data, :any_interface, :any_endpoint)

          Enum.each(any_interface_triggers, fn trigger ->
            TriggersHandler.incoming_data(
              trigger.trigger_targets,
              realm,
              device_id_string,
              interface_name,
              path,
              payload
            )
          end)

          any_endpoint_triggers =
            get_on_data_triggers(
              new_state,
              :on_incoming_data,
              interface_descriptor.interface_id,
              :any_endpoint
            )

          Enum.each(any_endpoint_triggers, fn trigger ->
            TriggersHandler.incoming_data(
              trigger.trigger_targets,
              realm,
              device_id_string,
              interface_name,
              path,
              payload
            )
          end)

          incoming_data_triggers =
            get_on_data_triggers(
              new_state,
              :on_incoming_data,
              interface_descriptor.interface_id,
              endpoint.endpoint_id,
              path,
              value
            )

          Enum.each(incoming_data_triggers, fn trigger ->
            TriggersHandler.incoming_data(
              trigger.trigger_targets,
              realm,
              device_id_string,
              interface_name,
              path,
              payload
            )
          end)

          value_change_triggers =
            get_on_data_triggers(
              new_state,
              :on_value_change,
              interface_descriptor.interface_id,
              endpoint.endpoint_id,
              path,
              value
            )

          value_change_applied_triggers =
            get_on_data_triggers(
              new_state,
              :on_value_change_applied,
              interface_descriptor.interface_id,
              endpoint.endpoint_id,
              path,
              value
            )

          path_created_triggers =
            get_on_data_triggers(
              new_state,
              :on_path_created,
              interface_descriptor.interface_id,
              endpoint.endpoint_id,
              path,
              value
            )

          path_removed_triggers =
            get_on_data_triggers(
              new_state,
              :on_path_removed,
              interface_descriptor.interface_id,
              endpoint.endpoint_id,
              path
            )

          previous_value =
            if value_change_triggers != [] or value_change_applied_triggers != [] or
                 path_created_triggers != [] do
              Queries.query_previous_value(
                db_client,
                interface_descriptor.aggregation,
                interface_descriptor.type,
                new_state.device_id,
                interface_descriptor,
                endpoint.endpoint_id,
                endpoint,
                path
              )
            else
              nil
            end

          # TODO: if retrieved_value is nil should we send an empty v, an empty document or an empty payload?
          old_bson_value =
            if previous_value do
              %{v: previous_value}
              |> Bson.encode()
            else
              <<>>
            end

          if old_bson_value != payload do
            Enum.each(value_change_triggers, fn trigger ->
              TriggersHandler.value_change(
                trigger.trigger_targets,
                realm,
                device_id_string,
                interface_name,
                path,
                old_bson_value,
                payload
              )
            end)
          end

          insert_result =
            Queries.insert_value_into_db(
              db_client,
              interface_descriptor.storage_type,
              new_state.device_id,
              interface_descriptor,
              endpoint.endpoint_id,
              endpoint,
              path,
              value,
              value_timestamp,
              timestamp
            )

          if old_bson_value == <<>> and payload != <<>> do
            Enum.each(path_created_triggers, fn trigger ->
              TriggersHandler.path_created(
                trigger.trigger_targets,
                realm,
                device_id_string,
                interface_name,
                path,
                payload
              )
            end)
          end

          if old_bson_value != <<>> and payload == <<>> do
            Enum.each(path_removed_triggers, fn trigger ->
              TriggersHandler.path_removed(
                trigger.trigger_targets,
                realm,
                device_id_string,
                interface_name,
                path
              )
            end)
          end

          if old_bson_value != payload do
            Enum.each(value_change_applied_triggers, fn trigger ->
              TriggersHandler.value_change_applied(
                trigger.trigger_targets,
                realm,
                device_id_string,
                interface_name,
                path,
                old_bson_value,
                payload
              )
            end)
          end

          insert_result
      end

    if result != :ok do
      Logger.debug("result is #{inspect(result)} further actions should be required.")
    end

    %{
      new_state
      | total_received_msgs: new_state.total_received_msgs + 1,
        total_received_bytes:
          new_state.total_received_bytes + byte_size(payload) + byte_size(interface) +
            byte_size(path)
    }
  end

  def handle_introspection(state, payload, delivery_tag, timestamp) do
    db_client = Queries.connect_to_db(state)

    new_state = execute_time_based_actions(state, timestamp, db_client)

    new_introspection_list = String.split(payload, ";")

    {db_introspection_map, db_introspection_minor_map} =
      List.foldl(new_introspection_list, {%{}, %{}}, fn introspection_item,
                                                        {introspection_map,
                                                         introspection_minor_map} ->
        [interface_name, major_version_string, minor_version_string] =
          String.split(introspection_item, ":")

        {major_version, garbage} = Integer.parse(major_version_string)

        if garbage != "" do
          Logger.warn(
            "#{new_state.realm}: Device #{pretty_device_id(new_state.device_id)} sent malformed introspection entry, found garbage in major version: #{
              garbage
            }."
          )
        end

        {minor_version, garbage} = Integer.parse(minor_version_string)

        if garbage != "" do
          Logger.warn(
            "#{new_state.realm}: Device #{pretty_device_id(new_state.device_id)} sent malformed introspection entry, found garbage in minor version: #{
              garbage
            }."
          )
        end

        introspection_map = Map.put(introspection_map, interface_name, major_version)
        introspection_minor_map = Map.put(introspection_minor_map, interface_name, minor_version)

        {introspection_map, introspection_minor_map}
      end)

    any_interface_id = SimpleTriggersProtobufUtils.any_interface_object_id()

    %{introspection_triggers: introspection_triggers} =
      populate_triggers_for_object!(new_state, db_client, any_interface_id, :any_interface)

    realm = new_state.realm
    device_id_string = pretty_device_id(new_state.device_id)

    on_introspection_targets =
      Map.get(introspection_triggers, {:on_incoming_introspection, :any_interface}, [])

    TriggersHandler.incoming_introspection(
      on_introspection_targets,
      realm,
      device_id_string,
      payload
    )

    # TODO: implement here object_id handling for a certain interface name. idea: introduce interface_family_id

    current_sorted_introspection =
      new_state.introspection
      |> Enum.map(fn x -> x end)
      |> Enum.sort()

    new_sorted_introspection =
      db_introspection_map
      |> Enum.map(fn x -> x end)
      |> Enum.sort()

    diff = List.myers_difference(current_sorted_introspection, new_sorted_introspection)

    Enum.each(diff, fn {change_type, changed_interfaces} ->
      case change_type do
        :ins ->
          Logger.debug(
            "#{new_state.realm}: Interfaces #{inspect(changed_interfaces)} have been added to #{
              pretty_device_id(new_state.device_id)
            } ."
          )

          Enum.each(changed_interfaces, fn {interface_name, interface_major} ->
            minor = Map.get(db_introspection_minor_map, interface_name)

            interface_added_targets =
              Map.get(introspection_triggers, {:on_interface_added, :any_interface}, [])

            TriggersHandler.interface_added(
              interface_added_targets,
              realm,
              device_id_string,
              interface_name,
              interface_major,
              minor
            )
          end)

        :del ->
          Logger.debug(
            "#{new_state.realm}: Interfaces #{inspect(changed_interfaces)} have been removed from #{
              pretty_device_id(new_state.device_id)
            } ."
          )

          Enum.each(changed_interfaces, fn {interface_name, interface_major} ->
            interface_removed_targets =
              Map.get(introspection_triggers, {:on_interface_deleted, :any_interface}, [])

            TriggersHandler.interface_removed(
              interface_removed_targets,
              realm,
              device_id_string,
              interface_name,
              interface_major
            )
          end)

        :eq ->
          Logger.debug(
            "#{new_state.realm}: Interfaces #{inspect(changed_interfaces)} have not changed on #{
              pretty_device_id(new_state.device_id)
            } ."
          )
      end
    end)

    # TODO: handle triggers for interface minor updates

    Queries.update_device_introspection!(
      db_client,
      new_state.device_id,
      db_introspection_map,
      db_introspection_minor_map
    )

    %{
      new_state
      | introspection: db_introspection_map,
        total_received_msgs: new_state.total_received_msgs + 1,
        total_received_bytes: new_state.total_received_bytes + byte_size(payload)
    }
  end

  def handle_control(state, "/producer/properties", <<0, 0, 0, 0>>, delivery_tag, timestamp) do
    db_client = Queries.connect_to_db(state)

    new_state = execute_time_based_actions(state, timestamp, db_client)

    operation_result = prune_device_properties(new_state, "", delivery_tag)

    if operation_result != :ok do
      Logger.debug("result is #{inspect(operation_result)} further actions should be required.")
    end

    # TODO: ACK here

    %{
      new_state
      | total_received_msgs: new_state.total_received_msgs + 1,
        total_received_bytes:
          new_state.total_received_bytes + byte_size(<<0, 0, 0, 0>>) +
            byte_size("/producer/properties")
    }
  end

  def handle_control(state, "/producer/properties", payload, delivery_tag, timestamp) do
    db_client = Queries.connect_to_db(state)

    new_state = execute_time_based_actions(state, timestamp, db_client)

    # TODO: check payload size, to avoid anoying crashes

    <<_size_header::size(32), zlib_payload::binary>> = payload

    decoded_payload = safe_deflate(zlib_payload)

    if decoded_payload != :error do
      operation_result = prune_device_properties(new_state, decoded_payload, delivery_tag)

      if operation_result != :ok do
        Logger.debug("result is #{inspect(operation_result)} further actions should be required.")
      end

      # TODO: ACK here
    end

    %{
      new_state
      | total_received_msgs: new_state.total_received_msgs + 1,
        total_received_bytes:
          new_state.total_received_bytes + byte_size(payload) + byte_size("/producer/properties")
    }
  end

  def handle_control(_state, "/emptyCache", _payload, _delivery_tag, _timestamp) do
    # TODO: implement empty cache
    raise "TODO"
  end

  def handle_control(_state, path, payload, _delivery_tag, _timestamp) do
    IO.puts("Control on #{path}, payload: #{inspect(payload)}")

    raise "TODO or unexpected"
  end

  def handle_install_volatile_trigger(
        state,
        object_id,
        object_type,
        parent_id,
        trigger_id,
        simple_trigger,
        trigger_target
      ) do
    trigger = SimpleTriggersProtobufUtils.deserialize_simple_trigger(simple_trigger)

    target =
      SimpleTriggersProtobufUtils.deserialize_trigger_target(trigger_target)
      |> Map.put(:simple_trigger_id, trigger_id)
      |> Map.put(:parent_trigger_id, parent_id)

    volatile_triggers_list = [
      {{object_id, object_type}, {trigger, target}} | state.volatile_triggers
    ]

    new_state = Map.put(state, :volatile_triggers, volatile_triggers_list)

    if Map.get(new_state.interface_ids_to_name, object_id) do
      load_trigger(new_state, trigger, target)
    else
      new_state
    end
  end

  # it takes some time before a trigger is not notified anymore
  # the data updater needs to forget the interface before.
  # Some spurious events might be sent afterwards, so the receiver needs to
  # deal with this issue and discard those events.
  # TODO: future version should completely forget it.
  def handle_delete_volatile_trigger(state, trigger_id) do
    updated_volatile_triggers =
      Enum.reject(state.volatile_triggers, fn {{obj_id, obj_type},
                                               {simple_trigger, trigger_target}} ->
        trigger_target.simple_trigger_id == trigger_id
      end)

    {:ok, Map.put(state, :volatile_triggers, updated_volatile_triggers)}
  end

  defp safe_deflate(zlib_payload) do
    z = :zlib.open()
    :ok = :zlib.inflateInit(z)

    {continue_flag, output_list} = :zlib.safeInflate(z, zlib_payload)

    uncompressed_size =
      List.foldl(output_list, 0, fn output_block, acc ->
        acc + byte_size(output_block)
      end)

    deflated_payload =
      if uncompressed_size < @max_uncompressed_payload_size do
        output_acc =
          List.foldl(output_list, <<>>, fn output_block, acc ->
            acc <> output_block
          end)

        safe_deflate_loop(z, output_acc, uncompressed_size, continue_flag)
      else
        :error
      end

    :zlib.inflateEnd(z)
    :zlib.close(z)

    deflated_payload
  end

  defp safe_deflate_loop(z, output_acc, size_acc, :continue) do
    {continue_flag, output_list} = :zlib.safeInflate(z, [])

    uncompressed_size =
      List.foldl(output_list, size_acc, fn output_block, acc ->
        acc + byte_size(output_block)
      end)

    if uncompressed_size < @max_uncompressed_payload_size do
      output_acc =
        List.foldl(output_list, output_acc, fn output_block, acc ->
          acc <> output_block
        end)

      safe_deflate_loop(z, output_acc, uncompressed_size, continue_flag)
    else
      :error
    end
  end

  defp safe_deflate_loop(_z, output_acc, _size_acc, :finished) do
    output_acc
  end

  defp reload_device_triggers_on_expiry(state, timestamp, db_client) do
    if state.last_device_triggers_refresh + @device_triggers_lifespan_decimicroseconds <=
         timestamp do
      any_device_id = SimpleTriggersProtobufUtils.any_device_object_id()

      state
      |> Map.put(:last_device_triggers_refresh, timestamp)
      |> Map.put(:device_triggers, %{})
      |> populate_triggers_for_object!(db_client, any_device_id, :any_device)
      |> populate_triggers_for_object!(db_client, state.device_id, :device)
    else
      state
    end
  end

  defp execute_time_based_actions(state, timestamp, db_client) do
    state
    |> Map.put(:last_seen_message, timestamp)
    |> purge_expired_interfaces(timestamp)
    |> reload_device_triggers_on_expiry(timestamp, db_client)
  end

  defp purge_expired_interfaces(state, timestamp) do
    expired =
      Enum.take_while(state.interfaces_by_expiry, fn {expiry, _interface} ->
        expiry <= timestamp
      end)

    new_interfaces_by_expiry = Enum.drop(state.interfaces_by_expiry, length(expired))

    interfaces_to_drop_list =
      for {_exp, iface} <- expired do
        iface
      end

    state
    |> forget_interfaces(interfaces_to_drop_list)
    |> Map.put(:interfaces_by_expiry, new_interfaces_by_expiry)
  end

  defp forget_interfaces(state, []) do
    state
  end

  defp forget_interfaces(state, interfaces_to_drop) do
    updated_triggers =
      Enum.reduce(interfaces_to_drop, state.data_triggers, fn iface, data_triggers ->
        interface_id = Map.fetch!(state.interfaces, iface).interface_id

        Enum.reject(data_triggers, fn {{event_type, iface_id, endpoint}, val} ->
          iface_id == interface_id
        end)
        |> Enum.into(%{})
      end)

    updated_mappings =
      Enum.reduce(interfaces_to_drop, state.mappings, fn iface, mappings ->
        interface_id = Map.fetch!(state.interfaces, iface).interface_id

        Enum.reject(mappings, fn {endpoint_id, mapping} ->
          mapping.interface_id == interface_id
        end)
        |> Enum.into(%{})
      end)

    updated_ids =
      Enum.reduce(interfaces_to_drop, state.interface_ids_to_name, fn iface, ids ->
        interface_id = Map.fetch!(state.interfaces, iface).interface_id
        Map.delete(ids, interface_id)
      end)

    updated_interfaces =
      Enum.reduce(interfaces_to_drop, state.interfaces, fn iface, ifaces ->
        Map.delete(ifaces, iface)
      end)

    %{
      state
      | interfaces: updated_interfaces,
        interface_ids_to_name: updated_ids,
        mappings: updated_mappings,
        data_triggers: updated_triggers
    }
  end

  defp maybe_handle_cache_miss(nil, interface_name, state, db_client) do
    major_version = Queries.interface_version!(db_client, state.device_id, interface_name)
    interface_row = Queries.retrieve_interface_row!(db_client, interface_name, major_version)

    interface_descriptor = InterfaceDescriptor.from_db_result!(interface_row)

    mappings = Queries.retrieve_interface_mappings!(db_client, interface_descriptor.interface_id)

    new_interfaces_by_expiry =
      state.interfaces_by_expiry ++
        [{state.last_seen_message + @interface_lifespan_decimicroseconds, interface_name}]

    new_state = %State{
      state
      | interfaces: Map.put(state.interfaces, interface_name, interface_descriptor),
        interface_ids_to_name:
          Map.put(state.interface_ids_to_name, interface_descriptor.interface_id, interface_name),
        interfaces_by_expiry: new_interfaces_by_expiry,
        mappings: Map.merge(state.mappings, mappings)
    }

    new_state =
      populate_triggers_for_object!(
        new_state,
        db_client,
        interface_descriptor.interface_id,
        :interface
      )

    {interface_descriptor, new_state}
  end

  defp maybe_handle_cache_miss(interface_descriptor, _interface_name, state, _db_client) do
    {interface_descriptor, state}
  end

  defp parse_device_properties_payload(_state, "") do
    MapSet.new()
  end

  defp parse_device_properties_payload(state, decoded_payload) do
    decoded_payload
    |> String.split(";")
    |> List.foldl(MapSet.new(), fn property_full_path, paths_acc ->
      if property_full_path != nil do
        case String.split(property_full_path, "/", parts: 2) do
          [interface, path] ->
            if Map.has_key?(state.introspection, interface) do
              MapSet.put(paths_acc, {interface, "/" <> path})
            else
              paths_acc
            end

          _ ->
            Logger.warn(
              "#{state.realm}: Device #{pretty_device_id(state.device_id)} sent a malformed entry in device properties control message: #{
                inspect(property_full_path)
              }."
            )

            paths_acc
        end
      else
        paths_acc
      end
    end)
  end

  defp prune_device_properties(state, decoded_payload, delivery_tag) do
    paths_set = parse_device_properties_payload(state, decoded_payload)

    db_client = Queries.connect_to_db(state)

    Enum.each(state.introspection, fn {interface, _} ->
      prune_interface(state, db_client, interface, paths_set, delivery_tag)
    end)

    :ok
  end

  defp prune_interface(state, db_client, interface, all_paths_set, delivery_tag) do
    {interface_descriptor, new_state} =
      maybe_handle_cache_miss(Map.get(state.interfaces, interface), interface, state, db_client)

    cond do
      interface_descriptor.type != :properties ->
        {:ok, state}

      interface_descriptor.ownership != :device ->
        Logger.warn(
          "#{state.realm}: Device #{pretty_device_id(state.device_id)} tried to write on server owned interface: #{
            interface
          }."
        )

        {:error, :maybe_outdated_introspection}

      true ->
        Enum.each(new_state.mappings, fn {endpoint_id, mapping} ->
          if mapping.interface_id == interface_descriptor.interface_id do
            all_paths_query =
              DatabaseQuery.new()
              |> DatabaseQuery.statement(
                "SELECT path FROM #{interface_descriptor.storage} WHERE device_id=:device_id AND interface_id=:interface_id AND endpoint_id=:endpoint_id"
              )
              |> DatabaseQuery.put(:device_id, state.device_id)
              |> DatabaseQuery.put(:interface_id, interface_descriptor.interface_id)
              |> DatabaseQuery.put(:endpoint_id, endpoint_id)

            DatabaseQuery.call!(db_client, all_paths_query)
            |> Enum.each(fn path_row ->
              path = path_row[:path]

              if not MapSet.member?(all_paths_set, {interface, path}) do
                device_id_string = pretty_device_id(state.device_id)

                {:ok, endpoint_id} =
                  EndpointsAutomaton.resolve_path(path, interface_descriptor.automaton)

                Queries.delete_property_from_db(
                  new_state,
                  db_client,
                  interface_descriptor,
                  endpoint_id,
                  path
                )

                path_removed_triggers =
                  get_on_data_triggers(
                    new_state,
                    :on_path_removed,
                    interface_descriptor.interface_id,
                    endpoint_id,
                    path
                  )

                Enum.each(path_removed_triggers, fn trigger ->
                  TriggersHandler.path_removed(
                    trigger.trigger_targets,
                    state.realm,
                    device_id_string,
                    interface_descriptor.name,
                    path
                  )
                end)
              end
            end)
          else
            :ok
          end
        end)

        {:ok, new_state}
    end
  end

  defp get_on_data_triggers(state, event, interface_id, endpoint_id) do
    key = {event, interface_id, endpoint_id}

    Map.get(state.data_triggers, key, [])
  end

  defp get_on_data_triggers(state, event, interface_id, endpoint_id, path, value \\ nil) do
    key = {event, interface_id, endpoint_id}

    candidate_triggers = Map.get(state.data_triggers, key, nil)

    if candidate_triggers do
      path_tokens = String.split(path, "/")

      for trigger <- candidate_triggers,
          path_matches?(path_tokens, trigger.path_match_tokens) and
            ValueMatchOperators.value_matches?(
              value,
              trigger.value_match_operator,
              trigger.known_value
            ) do
        trigger
      end
    else
      []
    end
  end

  defp path_matches?([], []) do
    true
  end

  defp path_matches?([path_token | path_tokens], [path_match_token | path_match_tokens]) do
    if path_token == path_match_token or path_match_token == "" do
      path_matches?(path_tokens, path_match_tokens)
    else
      false
    end
  end

  defp populate_triggers_for_object!(state, client, object_id, object_type) do
    object_type_int =
      case object_type do
        :device -> 1
        :interface -> 2
        :any_interface -> 3
        :any_device -> 4
      end

    simple_triggers_rows = Queries.query_simple_triggers!(client, object_id, object_type_int)

    new_state =
      Enum.reduce(simple_triggers_rows, state, fn row, state_acc ->
        trigger_id = row[:simple_trigger_id]
        parent_trigger_id = row[:parent_trigger_id]

        simple_trigger =
          SimpleTriggersProtobufUtils.deserialize_simple_trigger(row[:trigger_data])

        trigger_target =
          SimpleTriggersProtobufUtils.deserialize_trigger_target(row[:trigger_target])
          |> Map.put(:simple_trigger_id, trigger_id)
          |> Map.put(:parent_trigger_id, parent_trigger_id)

        load_trigger(state_acc, simple_trigger, trigger_target)
      end)

    Enum.reduce(new_state.volatile_triggers, new_state, fn {{obj_id, obj_type},
                                                            {simple_trigger, trigger_target}},
                                                           state_acc ->
      if obj_id == object_id and obj_type == object_type_int do
        load_trigger(state_acc, simple_trigger, trigger_target)
      else
        state_acc
      end
    end)
  end

  defp load_trigger(state, {:data_trigger, proto_buf_data_trigger}, trigger_target) do
    data_trigger =
      SimpleTriggersProtobufUtils.simple_trigger_to_data_trigger(proto_buf_data_trigger)

    data_triggers = state.data_triggers

    event_type =
      case proto_buf_data_trigger.data_trigger_type do
        :INCOMING_DATA ->
          :on_incoming_data

        # TODO: implement :on_value_change
        :VALUE_CHANGE ->
          :on_value_change

        # TODO: implement :on_value_changed
        :VALUE_CHANGE_APPLIED ->
          :on_value_change_applied

        # TODO: implement :on_path_created
        :PATH_CREATED ->
          :on_path_created

        :PATH_REMOVED ->
          :on_path_removed

        # TODO: implement :on_value_stored
        :VALUE_STORED ->
          :on_value_stored
      end

    interface_id = data_trigger.interface_id

    endpoint =
      if proto_buf_data_trigger.match_path != :any_endpoint and interface_id != :any_interface do
        interface_descriptor =
          Map.get(state.interfaces, Map.get(state.interface_ids_to_name, interface_id))

        {:ok, endpoint_id} =
          EndpointsAutomaton.resolve_path(
            proto_buf_data_trigger.match_path,
            interface_descriptor.automaton
          )

        endpoint_id
      else
        :any_endpoint
      end

    data_trigger_key = {event_type, interface_id, endpoint}

    candidate_triggers = Map.get(data_triggers, data_trigger_key)

    existing_trigger =
      if candidate_triggers do
        Enum.find(candidate_triggers, fn candidate ->
          DataTrigger.are_congruent?(candidate, data_trigger)
        end)
      else
        nil
      end

    targets =
      if existing_trigger do
        existing_trigger.trigger_targets
      else
        []
      end

    new_targets = [trigger_target | targets]
    new_data_trigger = %{data_trigger | trigger_targets: new_targets}

    new_triggers_chain =
      if candidate_triggers do
        List.foldl(candidate_triggers, [], fn t, acc ->
          if DataTrigger.are_congruent?(t, new_data_trigger) do
            [new_data_trigger | acc]
          else
            [t | acc]
          end
        end)
      else
        [new_data_trigger]
      end

    next_data_triggers = Map.put(data_triggers, data_trigger_key, new_triggers_chain)
    Map.put(state, :data_triggers, next_data_triggers)
  end

  defp load_trigger(
         state,
         {:introspection_trigger, proto_buf_introspection_trigger},
         trigger_target
       ) do
    introspection_triggers = state.introspection_triggers

    event_type =
      case proto_buf_introspection_trigger.change_type do
        # TODO: implement :on_incoming_introspection
        :INCOMING_INTROSPECTION ->
          :on_incoming_introspection

        :INTERFACE_ADDED ->
          :on_interface_added

        :INTERFACE_REMOVED ->
          :on_interface_removed

        # TODO: implement :on_interface_minor_updated
        :INTERFACE_MINOR_UPDATED ->
          :on_interface_minor_updated
      end

    introspection_trigger_key =
      {event_type, proto_buf_introspection_trigger.match_interface || :any_interface}

    existing_trigger_targets = Map.get(introspection_triggers, introspection_trigger_key, [])

    new_targets = [trigger_target | existing_trigger_targets]

    next_introspection_triggers =
      Map.put(introspection_triggers, introspection_trigger_key, new_targets)

    Map.put(state, :introspection_triggers, next_introspection_triggers)
  end

  defp load_trigger(state, {:device_trigger, proto_buf_device_trigger}, trigger_target) do
    device_triggers = state.device_triggers

    event_type =
      case proto_buf_device_trigger.device_event_type do
        :DEVICE_CONNECTED ->
          :on_device_connection

        :DEVICE_DISCONNECTED ->
          :on_device_disconnection

        # TODO: implement :on_empty_cache_received
        :DEVICE_EMPTY_CACHE_RECEIVED ->
          :on_empty_cache_received

        # TODO: implement :on_device_error
        :DEVICE_ERROR ->
          :on_device_error
      end

    existing_trigger_targets = Map.get(device_triggers, event_type, [])

    new_targets = [trigger_target | existing_trigger_targets]

    next_device_triggers = Map.put(device_triggers, event_type, new_targets)
    Map.put(state, :device_triggers, next_device_triggers)
  end

  defp pretty_device_id(device_id) do
    Base.url_encode64(device_id, padding: false)
  end
end
