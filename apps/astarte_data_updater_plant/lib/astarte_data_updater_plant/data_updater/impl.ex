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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Impl do
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.Core.CQLUtils
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.Mapping.ValueType
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.Core.Triggers.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger, as: ProtobufDataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils, as: SimpleTriggersProtobufUtils
  alias Astarte.DataAccess.Data
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Astarte.DataUpdaterPlant.DataUpdater.Cache
  alias Astarte.DataUpdaterPlant.DataUpdater.CachedPath
  alias Astarte.DataUpdaterPlant.DataUpdater.EventTypeUtils
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.RPC.VMQPlugin
  alias Astarte.DataUpdaterPlant.TriggersHandler
  alias Astarte.DataUpdaterPlant.TimeBasedActions
  require Logger

  def init_state(realm, device_id, message_tracker) do
    MessageTracker.register_data_updater(message_tracker)
    Process.monitor(message_tracker)

    new_state = %State{
      realm: realm,
      device_id: device_id,
      message_tracker: message_tracker,
      connected: true,
      groups: [],
      interfaces: %{},
      interface_ids_to_name: %{},
      interfaces_by_expiry: [],
      mappings: %{},
      paths_cache: Cache.new(Config.paths_cache_size!()),
      device_triggers: %{},
      data_triggers: %{},
      volatile_triggers: [],
      interface_exchanged_bytes: %{},
      interface_exchanged_msgs: %{},
      last_seen_message: 0,
      last_device_triggers_refresh: 0,
      last_groups_refresh: 0,
      trigger_id_to_policy_name: %{},
      discard_messages: false,
      last_deletion_in_progress_refresh: 0,
      last_datastream_maximum_retention_refresh: 0
    }

    encoded_device_id = Device.encode_device_id(device_id)
    Logger.metadata(realm: realm, device_id: encoded_device_id)
    Logger.info("Created device process.", tag: "device_process_created")

    stats_and_introspection =
      Queries.retrieve_device_stats_and_introspection!(new_state.realm, device_id)

    # TODO this could be a bang!
    {:ok, ttl} = Queries.fetch_datastream_maximum_storage_retention(new_state.realm)

    Map.merge(new_state, stats_and_introspection)
    |> Map.put(:datastream_maximum_storage_retention, ttl)
  end

  def handle_deactivation(_state) do
    Logger.info("Deactivated device process.", tag: "device_process_deactivated")

    :ok
  end

  def handle_connection(%State{discard_messages: true} = state, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_connection(state, ip_address_string, message_id, timestamp) do
    new_state = execute_time_based_actions(state, timestamp)

    timestamp_ms = div(timestamp, 10_000)

    ip_address_result =
      ip_address_string
      |> to_charlist()
      |> :inet.parse_address()

    ip_address =
      case ip_address_result do
        {:ok, ip_address} ->
          ip_address

        _ ->
          Logger.warning("Received invalid IP address #{ip_address_string}.")
          {0, 0, 0, 0}
      end

    Queries.set_device_connected!(
      new_state.realm,
      new_state.device_id,
      DateTime.from_unix!(timestamp_ms, :millisecond),
      ip_address
    )

    trigger_target_with_policy_list =
      Map.get(new_state.device_triggers, :on_device_connection, [])
      |> Enum.map(fn target ->
        {target, Map.get(state.trigger_id_to_policy_name, target.parent_trigger_id)}
      end)

    device_id_string = Device.encode_device_id(new_state.device_id)

    TriggersHandler.device_connected(
      trigger_target_with_policy_list,
      new_state.realm,
      device_id_string,
      ip_address_string,
      timestamp_ms
    )

    MessageTracker.ack_delivery(new_state.message_tracker, message_id)
    Logger.info("Device connected.", ip_address: ip_address_string, tag: "device_connected")

    :telemetry.execute([:astarte, :data_updater_plant, :data_updater, :device_connection], %{}, %{
      realm: new_state.realm
    })

    %{new_state | connected: true, last_seen_message: timestamp}
  end

  def handle_heartbeat(%State{discard_messages: true} = state, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  # TODO make this private when all heartbeats will be moved to internal
  def handle_heartbeat(state, message_id, timestamp) do
    new_state = execute_time_based_actions(state, timestamp)

    Queries.maybe_refresh_device_connected!(new_state.realm, new_state.device_id)

    MessageTracker.ack_delivery(new_state.message_tracker, message_id)
    Logger.info("Device heartbeat.", tag: "device_heartbeat")

    %{new_state | connected: true, last_seen_message: timestamp}
  end

  def handle_internal(state, "/heartbeat", _payload, message_id, timestamp) do
    {:continue, handle_heartbeat(state, message_id, timestamp)}
  end

  def handle_internal(%State{discard_messages: true} = state, "/f", _, message_id, _) do
    :ok = Queries.ack_end_device_deletion(state.realm, state.device_id)
    _ = Logger.info("End device deletion acked.", tag: "device_delete_ack")
    MessageTracker.ack_delivery(state.message_tracker, message_id)
    {:stop, state}
  end

  def handle_internal(state, path, payload, message_id, timestamp) do
    Logger.warning(
      "Unexpected internal message on #{path}, base64-encoded payload: #{inspect(Base.encode64(payload))}",
      tag: "unexpected_internal_message"
    )

    {:ok, new_state} = ask_clean_session(state, timestamp)
    MessageTracker.discard(new_state.message_tracker, message_id)

    :telemetry.execute(
      [:astarte, :data_updater_plant, :data_updater, :discarded_internal_message],
      %{},
      %{realm: new_state.realm}
    )

    base64_payload = Base.encode64(payload)

    error_metadata = %{
      "path" => inspect(path),
      "base64_payload" => base64_payload
    }

    # TODO maybe we don't want triggers on unexpected internal messages?
    execute_device_error_triggers(
      new_state,
      "unexpected_internal_message",
      error_metadata,
      timestamp
    )

    {:continue, update_stats(new_state, "", nil, path, payload)}
  end

  def start_device_deletion(state, timestamp) do
    # Device deletion is among time-based actions
    new_state = execute_time_based_actions(state, timestamp)

    {:ok, new_state}
  end

  def handle_disconnection(state, message_id, timestamp) do
    new_state =
      state
      |> execute_time_based_actions(timestamp)
      |> set_device_disconnected(timestamp)

    MessageTracker.ack_delivery(new_state.message_tracker, message_id)
    Logger.info("Device disconnected.", tag: "device_disconnected")

    %{new_state | last_seen_message: timestamp}
  end

  defp execute_incoming_data_triggers(
         state,
         device,
         interface,
         interface_id,
         path,
         endpoint_id,
         payload,
         value,
         timestamp
       ) do
    realm = state.realm

    # any interface triggers
    Core.Interface.get_on_data_triggers(state, :on_incoming_data, :any_interface, :any_endpoint)
    |> Enum.each(fn trigger ->
      target_with_policy_list = get_target_with_policy_list(state, trigger)

      TriggersHandler.incoming_data(
        target_with_policy_list,
        realm,
        device,
        interface,
        path,
        payload,
        timestamp
      )
    end)

    # any endpoint triggers
    Core.Interface.get_on_data_triggers(state, :on_incoming_data, interface_id, :any_endpoint)
    |> Enum.each(fn trigger ->
      target_with_policy_list = get_target_with_policy_list(state, trigger)

      TriggersHandler.incoming_data(
        target_with_policy_list,
        realm,
        device,
        interface,
        path,
        payload,
        timestamp
      )
    end)

    # incoming data triggers
    Core.Interface.get_on_data_triggers(
      state,
      :on_incoming_data,
      interface_id,
      endpoint_id,
      path,
      value
    )
    |> Enum.each(fn trigger ->
      target_with_policy_list = get_target_with_policy_list(state, trigger)

      TriggersHandler.incoming_data(
        target_with_policy_list,
        realm,
        device,
        interface,
        path,
        payload,
        timestamp
      )
    end)

    :ok
  end

  defp get_target_with_policy_list(state, trigger) do
    trigger.trigger_targets
    |> Enum.map(fn target ->
      {target, Map.get(state.trigger_id_to_policy_name, target.parent_trigger_id)}
    end)
  end

  defp get_value_change_triggers(state, interface_id, endpoint_id, path, value) do
    value_change_triggers =
      Core.Interface.get_on_data_triggers(
        state,
        :on_value_change,
        interface_id,
        endpoint_id,
        path,
        value
      )

    value_change_applied_triggers =
      Core.Interface.get_on_data_triggers(
        state,
        :on_value_change_applied,
        interface_id,
        endpoint_id,
        path,
        value
      )

    path_created_triggers =
      Core.Interface.get_on_data_triggers(
        state,
        :on_path_created,
        interface_id,
        endpoint_id,
        path,
        value
      )

    path_removed_triggers =
      Core.Interface.get_on_data_triggers(
        state,
        :on_path_removed,
        interface_id,
        endpoint_id,
        path
      )

    if value_change_triggers != [] or value_change_applied_triggers != [] or
         path_created_triggers != [] do
      {:ok,
       {value_change_triggers, value_change_applied_triggers, path_created_triggers,
        path_removed_triggers}}
    else
      {:no_value_change_triggers, nil}
    end
  end

  defp execute_pre_change_triggers(
         {value_change_triggers, _, _, _},
         realm,
         device_id_string,
         interface_name,
         path,
         previous_value,
         value,
         timestamp,
         trigger_id_to_policy_name_map
       ) do
    old_bson_value = Cyanide.encode!(%{v: previous_value})
    payload = Cyanide.encode!(%{v: value})

    if previous_value != value do
      Enum.each(value_change_triggers, fn trigger ->
        trigger_target_with_policy_list =
          trigger.trigger_targets
          |> Enum.map(fn target ->
            {target, Map.get(trigger_id_to_policy_name_map, target.parent_trigger_id)}
          end)

        TriggersHandler.value_change(
          trigger_target_with_policy_list,
          realm,
          device_id_string,
          interface_name,
          path,
          old_bson_value,
          payload,
          timestamp
        )
      end)
    end

    :ok
  end

  defp execute_post_change_triggers(
         {_, value_change_applied_triggers, path_created_triggers, path_removed_triggers},
         realm,
         device,
         interface,
         path,
         previous_value,
         value,
         timestamp,
         trigger_id_to_policy_name_map
       ) do
    old_bson_value = Cyanide.encode!(%{v: previous_value})
    payload = Cyanide.encode!(%{v: value})

    if previous_value == nil and value != nil do
      Enum.each(path_created_triggers, fn trigger ->
        target_with_policy_list =
          trigger.trigger_targets
          |> Enum.map(fn target ->
            {target, Map.get(trigger_id_to_policy_name_map, target.parent_trigger_id)}
          end)

        TriggersHandler.path_created(
          target_with_policy_list,
          realm,
          device,
          interface,
          path,
          payload,
          timestamp
        )
      end)
    end

    if previous_value != nil and value == nil do
      Enum.each(path_removed_triggers, fn trigger ->
        target_with_policy_list =
          trigger.trigger_targets
          |> Enum.map(fn target ->
            {target, Map.get(trigger_id_to_policy_name_map, target.parent_trigger_id)}
          end)

        TriggersHandler.path_removed(
          target_with_policy_list,
          realm,
          device,
          interface,
          path,
          timestamp
        )
      end)
    end

    if previous_value != value do
      Enum.each(value_change_applied_triggers, fn trigger ->
        target_with_policy_list =
          trigger.trigger_targets
          |> Enum.map(fn target ->
            {target, Map.get(trigger_id_to_policy_name_map, target.parent_trigger_id)}
          end)

        TriggersHandler.value_change_applied(
          target_with_policy_list,
          realm,
          device,
          interface,
          path,
          old_bson_value,
          payload,
          timestamp
        )
      end)
    end

    :ok
  end

  defp execute_device_error_triggers(state, error_name, error_metadata \\ %{}, timestamp) do
    timestamp_ms = div(timestamp, 10_000)

    trigger_target_with_policy_list =
      Map.get(state.device_triggers, :on_device_error, [])
      |> Enum.map(fn target ->
        {target, Map.get(state.trigger_id_to_policy_name, target.parent_trigger_id)}
      end)

    device_id_string = Device.encode_device_id(state.device_id)

    TriggersHandler.device_error(
      trigger_target_with_policy_list,
      state.realm,
      device_id_string,
      error_name,
      error_metadata,
      timestamp_ms
    )

    :ok
  end

  def handle_data(%State{discard_messages: true} = state, _, _, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_data(state, interface, path, payload, message_id, timestamp) do
    new_state = execute_time_based_actions(state, timestamp)

    with :ok <- validate_interface(interface),
         :ok <- validate_path(path),
         maybe_descriptor <- Map.get(new_state.interfaces, interface),
         {:ok, interface_descriptor, new_state} <-
           Core.Interface.maybe_handle_cache_miss(maybe_descriptor, interface, new_state),
         :ok <- can_write_on_interface?(interface_descriptor),
         interface_id <- interface_descriptor.interface_id,
         {:ok, mapping} <-
           Core.Interface.resolve_path(path, interface_descriptor, new_state.mappings),
         endpoint_id = mapping.endpoint_id,
         db_retention_policy = mapping.database_retention_policy,
         db_ttl = mapping.database_retention_ttl,
         {value, value_timestamp, _metadata} <-
           PayloadsDecoder.decode_bson_payload(payload, timestamp),
         expected_types <-
           Core.Interface.extract_expected_types(
             path,
             interface_descriptor,
             mapping,
             new_state.mappings
           ),
         :ok <- validate_value_type(expected_types, value) do
      device_id_string = Device.encode_device_id(new_state.device_id)

      maybe_explicit_value_timestamp =
        if mapping.explicit_timestamp do
          value_timestamp
        else
          div(timestamp, 10000)
        end

      execute_incoming_data_triggers(
        new_state,
        device_id_string,
        interface_descriptor.name,
        interface_id,
        path,
        endpoint_id,
        payload,
        value,
        maybe_explicit_value_timestamp
      )

      {has_change_triggers, change_triggers} =
        get_value_change_triggers(new_state, interface_id, endpoint_id, path, value)

      previous_value =
        with {:has_change_triggers, :ok} <- {:has_change_triggers, has_change_triggers},
             {:ok, property_value} <-
               Data.fetch_property(
                 new_state.realm,
                 new_state.device_id,
                 interface_descriptor,
                 mapping,
                 path
               ) do
          property_value
        else
          {:has_change_triggers, _not_ok} ->
            nil

          {:error, :property_not_set} ->
            nil
        end

      if has_change_triggers == :ok do
        :ok =
          execute_pre_change_triggers(
            change_triggers,
            new_state.realm,
            device_id_string,
            interface_descriptor.name,
            path,
            previous_value,
            value,
            maybe_explicit_value_timestamp,
            state.trigger_id_to_policy_name
          )
      end

      realm_max_ttl = state.datastream_maximum_storage_retention

      db_max_ttl =
        cond do
          db_retention_policy == :use_ttl and is_integer(realm_max_ttl) ->
            min(db_ttl, realm_max_ttl)

          db_retention_policy == :use_ttl ->
            db_ttl

          is_integer(realm_max_ttl) ->
            realm_max_ttl

          true ->
            nil
        end

      cond do
        interface_descriptor.type == :datastream and value != nil ->
          :ok =
            cond do
              Cache.has_key?(new_state.paths_cache, {interface, path}) ->
                :ok

              is_still_valid?(
                # TODO this is now a bang!
                Queries.fetch_path_expiry(
                  new_state.realm,
                  new_state.device_id,
                  interface_descriptor,
                  mapping,
                  path
                ),
                db_max_ttl
              ) ->
                :ok

              true ->
                Queries.insert_path_into_db(
                  new_state.realm,
                  new_state.device_id,
                  interface_descriptor,
                  mapping,
                  path,
                  maybe_explicit_value_timestamp,
                  timestamp,
                  ttl: path_ttl(db_max_ttl)
                )
            end

        interface_descriptor.type == :datastream ->
          Logger.warning("Tried to unset a datastream.", tag: "unset_on_datastream")
          MessageTracker.discard(new_state.message_tracker, message_id)

          :telemetry.execute(
            [:astarte, :data_updater_plant, :data_updater, :discarded_message],
            %{},
            %{realm: new_state.realm}
          )

          base64_payload = Base.encode64(payload)

          error_metadata = %{
            "interface" => inspect(interface),
            "path" => inspect(path),
            "base64_payload" => base64_payload
          }

          execute_device_error_triggers(
            new_state,
            "unset_on_datastream",
            error_metadata,
            timestamp
          )

          raise "Unsupported"

        true ->
          :ok
      end

      # TODO: handle insert failures here
      insert_result =
        Queries.insert_value_into_db(
          new_state.realm,
          new_state.device_id,
          interface_descriptor,
          mapping,
          path,
          value,
          maybe_explicit_value_timestamp,
          timestamp,
          ttl: db_max_ttl
        )

      case insert_result do
        {:error, :unset_not_allowed} ->
          Logger.warning("Tried to unset a property with `allow_unset`=false.",
            tag: "unset_not_allowed"
          )

          MessageTracker.discard(new_state.message_tracker, message_id)

          :telemetry.execute(
            [:astarte, :data_updater_plant, :data_updater, :discarded_message],
            %{},
            %{realm: new_state.realm}
          )

          base64_payload = Base.encode64(payload)

          error_metadata = %{
            "interface" => inspect(interface),
            "path" => inspect(path),
            "base64_payload" => base64_payload
          }

          execute_device_error_triggers(
            new_state,
            "unset_not_allowed",
            error_metadata,
            timestamp
          )

        :ok ->
          if has_change_triggers == :ok do
            :ok =
              execute_post_change_triggers(
                change_triggers,
                new_state.realm,
                device_id_string,
                interface_descriptor.name,
                path,
                previous_value,
                value,
                maybe_explicit_value_timestamp,
                state.trigger_id_to_policy_name
              )
          end

          ttl = db_max_ttl
          paths_cache = Cache.put(new_state.paths_cache, {interface, path}, %CachedPath{}, ttl)
          new_state = %{new_state | paths_cache: paths_cache}

          MessageTracker.ack_delivery(new_state.message_tracker, message_id)

          :telemetry.execute(
            [:astarte, :data_updater_plant, :data_updater, :processed_message],
            %{},
            %{
              realm: new_state.realm,
              interface_type: interface_descriptor.type
            }
          )

          update_stats(new_state, interface, interface_descriptor.major_version, path, payload)
      end
    else
      {:error, :cannot_write_on_server_owned_interface} ->
        Logger.warning(
          "Tried to write on server owned interface: #{interface} on " <>
            "path: #{path}, base64-encoded payload: #{inspect(Base.encode64(payload))}, timestamp: #{inspect(timestamp)}.",
          tag: "write_on_server_owned_interface"
        )

        {:ok, new_state} = ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        base64_payload = Base.encode64(payload)

        error_metadata = %{
          "interface" => inspect(interface),
          "path" => inspect(path),
          "base64_payload" => base64_payload
        }

        execute_device_error_triggers(
          new_state,
          "write_on_server_owned_interface",
          error_metadata,
          timestamp
        )

        update_stats(new_state, interface, nil, path, payload)

      {:error, :invalid_interface} ->
        Logger.warning("Received invalid interface: #{inspect(interface)}.",
          tag: "invalid_interface"
        )

        {:ok, new_state} = ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        base64_payload = Base.encode64(payload)

        error_metadata = %{
          "interface" => inspect(interface),
          "path" => inspect(path),
          "base64_payload" => base64_payload
        }

        execute_device_error_triggers(
          new_state,
          "invalid_interface",
          error_metadata,
          timestamp
        )

        # We dont't update stats on an invalid interface
        new_state

      {:error, :invalid_path} ->
        Logger.warning("Received invalid path: #{inspect(path)}.", tag: "invalid_path")
        {:ok, new_state} = ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        base64_payload = Base.encode64(payload)

        error_metadata = %{
          "interface" => inspect(interface),
          "path" => inspect(path),
          "base64_payload" => base64_payload
        }

        execute_device_error_triggers(new_state, "invalid_path", error_metadata, timestamp)

        update_stats(new_state, interface, nil, path, payload)

      {:error, :mapping_not_found} ->
        Logger.warning("Mapping not found for #{interface}#{path}. Maybe outdated introspection?",
          tag: "mapping_not_found"
        )

        {:ok, new_state} = ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        base64_payload = Base.encode64(payload)

        error_metadata = %{
          "interface" => inspect(interface),
          "path" => inspect(path),
          "base64_payload" => base64_payload
        }

        execute_device_error_triggers(new_state, "mapping_not_found", error_metadata, timestamp)

        update_stats(new_state, interface, nil, path, payload)

      {:error, :interface_loading_failed} ->
        Logger.warning("Cannot load interface: #{interface}.", tag: "interface_loading_failed")
        # TODO: think about additional actions since the problem
        # could be a missing interface in the DB
        {:ok, new_state} = ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        base64_payload = Base.encode64(payload)

        error_metadata = %{
          "interface" => inspect(interface),
          "path" => inspect(path),
          "base64_payload" => base64_payload
        }

        execute_device_error_triggers(
          new_state,
          "interface_loading_failed",
          error_metadata,
          timestamp
        )

        update_stats(new_state, interface, nil, path, payload)

      {:guessed, _guessed_endpoints} ->
        Logger.warning("Mapping guessed for #{interface}#{path}. Maybe outdated introspection?",
          tag: "ambiguous_path"
        )

        {:ok, new_state} = ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        base64_payload = Base.encode64(payload)

        error_metadata = %{
          "interface" => inspect(interface),
          "path" => inspect(path),
          "base64_payload" => base64_payload
        }

        execute_device_error_triggers(
          new_state,
          "ambiguous_path",
          error_metadata,
          timestamp
        )

        update_stats(new_state, interface, nil, path, payload)

      {:error, :undecodable_bson_payload} ->
        Logger.warning(
          "Invalid BSON base64-encoded payload: #{inspect(Base.encode64(payload))} sent to #{interface}#{path}.",
          tag: "undecodable_bson_payload"
        )

        {:ok, new_state} = ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        base64_payload = Base.encode64(payload)

        error_metadata = %{
          "interface" => inspect(interface),
          "path" => inspect(path),
          "base64_payload" => base64_payload
        }

        execute_device_error_triggers(
          new_state,
          "undecodable_bson_payload",
          error_metadata,
          timestamp
        )

        update_stats(new_state, interface, nil, path, payload)

      {:error, :unexpected_value_type} ->
        Logger.warning(
          "Received invalid value: #{inspect(Base.encode64(payload))} sent to #{interface}#{path}.",
          tag: "unexpected_value_type"
        )

        {:ok, new_state} = ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        base64_payload = Base.encode64(payload)

        error_metadata = %{
          "interface" => inspect(interface),
          "path" => inspect(path),
          "base64_payload" => base64_payload
        }

        execute_device_error_triggers(
          new_state,
          "unexpected_value_type",
          error_metadata,
          timestamp
        )

        update_stats(new_state, interface, nil, path, payload)

      {:error, :value_size_exceeded} ->
        Logger.warning(
          "Received huge base64-encoded payload: #{inspect(Base.encode64(payload))} sent to #{interface}#{path}.",
          tag: "value_size_exceeded"
        )

        {:ok, new_state} = ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        base64_payload = Base.encode64(payload)

        error_metadata = %{
          "interface" => inspect(interface),
          "path" => inspect(path),
          "base64_payload" => base64_payload
        }

        execute_device_error_triggers(new_state, "value_size_exceeded", error_metadata, timestamp)

        update_stats(new_state, interface, nil, path, payload)

      {:error, :unexpected_object_key} ->
        base64_payload = Base.encode64(payload)

        Logger.warning(
          "Received object with unexpected key, object base64 is: #{base64_payload} sent to #{interface}#{path}.",
          tag: "unexpected_object_key"
        )

        {:ok, new_state} = ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        error_metadata = %{
          "interface" => inspect(interface),
          "path" => inspect(path),
          "base64_payload" => base64_payload
        }

        execute_device_error_triggers(
          new_state,
          "unexpected_object_key",
          error_metadata,
          timestamp
        )

        update_stats(new_state, interface, nil, path, payload)
    end
  end

  defp path_ttl(nil) do
    nil
  end

  defp path_ttl(retention_secs) do
    retention_secs * 2 + div(retention_secs, 2)
  end

  defp is_still_valid?({:error, :property_not_set}, _ttl) do
    false
  end

  defp is_still_valid?({:ok, :no_expiry}, _ttl) do
    true
  end

  defp is_still_valid?({:ok, _expiry_date}, nil) do
    false
  end

  defp is_still_valid?({:ok, expiry_date}, ttl) do
    expiry_secs = DateTime.to_unix(expiry_date)

    now_secs =
      DateTime.utc_now()
      |> DateTime.to_unix()

    # 3600 seconds is one hour
    # this adds 1 hour of tolerance to clock synchronization issues
    now_secs + ttl + 3600 < expiry_secs
  end

  defp validate_interface(interface) do
    if String.valid?(interface) do
      :ok
    else
      {:error, :invalid_interface}
    end
  end

  defp validate_path(path) do
    cond do
      # Make sure the path is a valid unicode string
      not String.valid?(path) ->
        {:error, :invalid_path}

      # TODO: this is a temporary fix to work around a bug in EndpointsAutomaton.resolve_path/2
      String.contains?(path, "//") ->
        {:error, :invalid_path}

      true ->
        :ok
    end
  end

  # TODO: We need tests for this function
  def validate_value_type(expected_type, %DateTime{} = value) do
    ValueType.validate_value(expected_type, value)
  end

  # From Cyanide 2.0, binaries are decoded as %Cyanide.Binary{}
  def validate_value_type(expected_type, %Cyanide.Binary{} = value) do
    %Cyanide.Binary{subtype: _subtype, data: bin} = value
    validate_value_type(expected_type, bin)
  end

  # Explicitly match on all other structs to avoid pattern matching them as maps below
  def validate_value_type(_expected_type, %_{} = _unsupported_struct) do
    {:error, :unexpected_value_type}
  end

  def validate_value_type(%{} = expected_types, %{} = object) do
    Enum.reduce_while(object, :ok, fn {key, value}, _acc ->
      with {:ok, expected_type} <- Map.fetch(expected_types, key),
           :ok <- ValueType.validate_value(expected_type, value) do
        {:cont, :ok}
      else
        {:error, reason} ->
          {:halt, {:error, reason}}

        :error ->
          Logger.warning("Unexpected key #{inspect(key)} in object #{inspect(object)}.",
            tag: "unexpected_object_key"
          )

          {:halt, {:error, :unexpected_object_key}}
      end
    end)
  end

  # TODO: we should test for this kind of unexpected messages
  # We expected an individual value, but we received an aggregated
  def validate_value_type(_expected_types, %{} = _object) do
    {:error, :unexpected_value_type}
  end

  # TODO: we should test for this kind of unexpected messages
  # We expected an aggregated, but we received an individual
  def validate_value_type(%{} = _expected_types, _object) do
    {:error, :unexpected_value_type}
  end

  def validate_value_type(expected_type, value) do
    if value != nil do
      ValueType.validate_value(expected_type, value)
    else
      :ok
    end
  end

  defp update_stats(state, interface, major, path, payload) do
    exchanged_bytes = byte_size(payload) + byte_size(interface) + byte_size(path)

    :telemetry.execute(
      [:astarte, :data_updater_plant, :data_updater, :exchanged_bytes],
      %{bytes: exchanged_bytes},
      %{realm: state.realm}
    )

    %{
      state
      | total_received_msgs: state.total_received_msgs + 1,
        total_received_bytes: state.total_received_bytes + exchanged_bytes
    }
    |> update_interface_stats(interface, major, path, payload)
  end

  defp update_interface_stats(state, interface, major, _path, _payload)
       when interface == "" or major == nil do
    # Skip when we can't identify a specific major or interface is empty (e.g. control messages)
    # TODO: restructure code to access major version even in the else branch of handle_data
    state
  end

  defp update_interface_stats(state, interface, major, path, payload) do
    %State{
      initial_interface_exchanged_bytes: initial_interface_exchanged_bytes,
      initial_interface_exchanged_msgs: initial_interface_exchanged_msgs,
      interface_exchanged_bytes: interface_exchanged_bytes,
      interface_exchanged_msgs: interface_exchanged_msgs
    } = state

    bytes = byte_size(payload) + byte_size(interface) + byte_size(path)

    # If present, get exchanged bytes from live count, otherwise fallback to initial
    # count and in case nothing is there too, fallback to 0
    exchanged_bytes =
      Map.get_lazy(interface_exchanged_bytes, {interface, major}, fn ->
        Map.get(initial_interface_exchanged_bytes, {interface, major}, 0)
      end)

    # As above but with msgs
    exchanged_msgs =
      Map.get_lazy(interface_exchanged_msgs, {interface, major}, fn ->
        Map.get(initial_interface_exchanged_msgs, {interface, major}, 0)
      end)

    updated_interface_exchanged_bytes =
      Map.put(interface_exchanged_bytes, {interface, major}, exchanged_bytes + bytes)

    updated_interface_exchanged_msgs =
      Map.put(interface_exchanged_msgs, {interface, major}, exchanged_msgs + 1)

    %{
      state
      | interface_exchanged_bytes: updated_interface_exchanged_bytes,
        interface_exchanged_msgs: updated_interface_exchanged_msgs
    }
  end

  def handle_introspection(%State{discard_messages: true} = state, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_introspection(state, payload, message_id, timestamp) do
    with {:ok, new_introspection_list} <- PayloadsDecoder.parse_introspection(payload) do
      Core.Device.process_introspection(
        state,
        new_introspection_list,
        payload,
        message_id,
        timestamp
      )
    else
      {:error, :invalid_introspection} ->
        Logger.warning("Discarding invalid introspection: #{inspect(Base.encode64(payload))}.",
          tag: "invalid_introspection"
        )

        {:ok, new_state} = ask_clean_session(state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_introspection],
          %{},
          %{realm: new_state.realm}
        )

        base64_payload = Base.encode64(payload)

        error_metadata = %{
          "base64_payload" => base64_payload
        }

        execute_device_error_triggers(
          new_state,
          "invalid_introspection",
          error_metadata,
          timestamp
        )

        update_stats(new_state, "", nil, "", payload)
    end
  end

  def handle_control(%State{discard_messages: true} = state, _, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_control(state, "/producer/properties", <<0, 0, 0, 0>>, message_id, timestamp) do
    new_state = execute_time_based_actions(state, timestamp)

    timestamp_ms = div(timestamp, 10_000)

    :ok = prune_device_properties(new_state, "", timestamp_ms)

    MessageTracker.ack_delivery(new_state.message_tracker, message_id)

    %{
      new_state
      | total_received_msgs: new_state.total_received_msgs + 1,
        total_received_bytes:
          new_state.total_received_bytes + byte_size(<<0, 0, 0, 0>>) +
            byte_size("/producer/properties")
    }
  end

  def handle_control(state, "/producer/properties", payload, message_id, timestamp) do
    new_state = execute_time_based_actions(state, timestamp)

    timestamp_ms = div(timestamp, 10_000)

    # TODO: check payload size, to avoid anoying crashes

    <<_size_header::size(32), zlib_payload::binary>> = payload

    case PayloadsDecoder.safe_inflate(zlib_payload) do
      {:ok, decoded_payload} ->
        :ok = prune_device_properties(new_state, decoded_payload, timestamp_ms)
        MessageTracker.ack_delivery(new_state.message_tracker, message_id)

        %{
          new_state
          | total_received_msgs: new_state.total_received_msgs + 1,
            total_received_bytes:
              new_state.total_received_bytes + byte_size(payload) +
                byte_size("/producer/properties")
        }

      :error ->
        Logger.warning("Invalid purge_properties payload", tag: "purge_properties_error")

        {:ok, new_state} = ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        new_state
    end
  end

  def handle_control(state, "/emptyCache", _payload, message_id, timestamp) do
    new_state = execute_time_based_actions(state, timestamp)

    with :ok <- send_control_consumer_properties(state),
         {:ok, new_state} <- resend_all_properties(state),
         :ok <- Queries.set_pending_empty_cache(new_state.realm, new_state.device_id, false) do
      MessageTracker.ack_delivery(state.message_tracker, message_id)

      :telemetry.execute(
        [:astarte, :data_updater_plant, :data_updater, :processed_empty_cache],
        %{},
        %{realm: new_state.realm}
      )

      new_state
    else
      {:error, :session_not_found} ->
        Logger.warning("Cannot push data to device.", tag: "device_session_not_found")

        {:ok, new_state} = ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        execute_device_error_triggers(new_state, "device_session_not_found", timestamp)

        new_state

      {:error, :sending_properties_to_interface_failed} ->
        Logger.warning("Cannot resend properties to interface",
          tag: "resend_interface_properties_failed"
        )

        {:ok, new_state} = ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        execute_device_error_triggers(
          new_state,
          "resend_interface_properties_failed",
          timestamp
        )

        new_state

      {:error, reason} ->
        Logger.warning("Unhandled error during emptyCache: #{inspect(reason)}",
          tag: "empty_cache_error"
        )

        {:ok, new_state} = ask_clean_session(new_state, timestamp)
        MessageTracker.discard(new_state.message_tracker, message_id)

        :telemetry.execute(
          [:astarte, :data_updater_plant, :data_updater, :discarded_message],
          %{},
          %{realm: new_state.realm}
        )

        error_metadata = %{"reason" => inspect(reason)}

        execute_device_error_triggers(new_state, "empty_cache_error", error_metadata, timestamp)

        new_state
    end
  end

  def handle_control(state, path, payload, message_id, timestamp) do
    Logger.warning(
      "Unexpected control on #{path}, base64-encoded payload: #{inspect(Base.encode64(payload))}",
      tag: "unexpected_control_message"
    )

    {:ok, new_state} = ask_clean_session(state, timestamp)
    MessageTracker.discard(new_state.message_tracker, message_id)

    :telemetry.execute(
      [:astarte, :data_updater_plant, :data_updater, :discarded_control_message],
      %{},
      %{realm: new_state.realm}
    )

    base64_payload = Base.encode64(payload)

    error_metadata = %{
      "path" => inspect(path),
      "base64_payload" => base64_payload
    }

    execute_device_error_triggers(
      new_state,
      "unexpected_control_message",
      error_metadata,
      timestamp
    )

    update_stats(new_state, "", nil, path, payload)
  end

  def handle_install_volatile_trigger(
        %State{discard_messages: true} = state,
        _,
        message_id,
        _
      ) do
    MessageTracker.ack_delivery(state.message_tracker, message_id)
    state
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

    if Map.has_key?(new_state.interface_ids_to_name, object_id) do
      interface_name = Map.get(new_state.interface_ids_to_name, object_id)
      %InterfaceDescriptor{automaton: automaton} = new_state.interfaces[interface_name]

      case trigger do
        {:data_trigger, %ProtobufDataTrigger{match_path: "/*"}} ->
          {:ok, Core.Trigger.load_trigger(new_state, trigger, target)}

        {:data_trigger, %ProtobufDataTrigger{match_path: match_path}} ->
          with {:ok, _endpoint_id} <- EndpointsAutomaton.resolve_path(match_path, automaton) do
            {:ok, Core.Trigger.load_trigger(new_state, trigger, target)}
          else
            {:guessed, _} ->
              # State rollback here
              {{:error, :invalid_match_path}, state}

            {:error, :not_found} ->
              # State rollback here
              {{:error, :invalid_match_path}, state}
          end
      end
    else
      case trigger do
        {:data_trigger, %ProtobufDataTrigger{interface_name: "*"}} ->
          {:ok, Core.Trigger.load_trigger(new_state, trigger, target)}

        {:data_trigger,
         %ProtobufDataTrigger{
           interface_name: interface_name,
           interface_major: major,
           match_path: "/*"
         }} ->
          with :ok <-
                 InterfaceQueries.check_if_interface_exists(state.realm, interface_name, major) do
            {:ok, new_state}
          else
            {:error, reason} ->
              # State rollback here
              {{:error, reason}, state}
          end

        {:data_trigger,
         %ProtobufDataTrigger{
           interface_name: interface_name,
           interface_major: major,
           match_path: match_path
         }} ->
          with {:ok, %InterfaceDescriptor{automaton: automaton}} <-
                 InterfaceQueries.fetch_interface_descriptor(state.realm, interface_name, major),
               {:ok, _endpoint_id} <- EndpointsAutomaton.resolve_path(match_path, automaton) do
            {:ok, new_state}
          else
            {:error, :not_found} ->
              {{:error, :invalid_match_path}, state}

            {:guessed, _} ->
              {{:error, :invalid_match_path}, state}

            {:error, reason} ->
              # State rollback here
              {{:error, reason}, state}
          end

        {:device_trigger, _} ->
          {:ok, Core.Trigger.load_trigger(new_state, trigger, target)}
      end
    end
  end

  def handle_delete_volatile_trigger(%State{discard_messages: true} = state, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_delete_volatile_trigger(state, trigger_id) do
    {new_volatile, maybe_trigger} =
      Enum.reduce(state.volatile_triggers, {[], nil}, fn item, {acc, found} ->
        {_, {_simple_trigger, trigger_target}} = item

        if trigger_target.simple_trigger_id == trigger_id do
          {acc, item}
        else
          {[item | acc], found}
        end
      end)

    case maybe_trigger do
      {{obj_id, obj_type}, {simple_trigger, trigger_target}} ->
        %{state | volatile_triggers: new_volatile}
        |> delete_volatile_trigger({obj_id, obj_type}, {simple_trigger, trigger_target})

      nil ->
        {:ok, state}
    end
  end

  defp delete_volatile_trigger(
         state,
         {obj_id, _obj_type},
         {{:data_trigger, proto_buf_data_trigger}, trigger_target_to_be_deleted}
       ) do
    if Map.get(state.interface_ids_to_name, obj_id) do
      data_trigger_to_be_deleted =
        SimpleTriggersProtobufUtils.simple_trigger_to_data_trigger(proto_buf_data_trigger)

      data_triggers = state.data_triggers

      event_type =
        EventTypeUtils.pretty_data_trigger_type(proto_buf_data_trigger.data_trigger_type)

      data_trigger_key =
        Core.DataTrigger.data_trigger_to_key(state, data_trigger_to_be_deleted, event_type)

      existing_triggers_for_key = Map.get(data_triggers, data_trigger_key, [])

      # Separate triggers for key between the trigger congruent with the one being deleted
      # and all the other triggers
      {congruent_data_trigger_for_key, other_data_triggers_for_key} =
        Enum.reduce(existing_triggers_for_key, {nil, []}, fn
          trigger, {congruent_data_trigger_for_key, other_data_triggers_for_key} ->
            if DataTrigger.are_congruent?(trigger, data_trigger_to_be_deleted) do
              {trigger, other_data_triggers_for_key}
            else
              {congruent_data_trigger_for_key, [trigger | other_data_triggers_for_key]}
            end
        end)

      next_data_triggers_for_key =
        case congruent_data_trigger_for_key do
          nil ->
            # Trying to delete an unexisting volatile trigger, just return old data triggers
            existing_triggers_for_key

          %DataTrigger{trigger_targets: [^trigger_target_to_be_deleted]} ->
            # The target of the deleted trigger was the only target, just remove it
            other_data_triggers_for_key

          %DataTrigger{trigger_targets: targets} ->
            # The trigger has other targets, drop the one that is being deleted and update
            new_trigger_targets = Enum.reject(targets, &(&1 == trigger_target_to_be_deleted))

            new_congruent_data_trigger_for_key = %{
              congruent_data_trigger_for_key
              | trigger_targets: new_trigger_targets
            }

            [new_congruent_data_trigger_for_key | other_data_triggers_for_key]
        end

      next_data_triggers =
        if is_list(next_data_triggers_for_key) and length(next_data_triggers_for_key) > 0 do
          Map.put(data_triggers, data_trigger_key, next_data_triggers_for_key)
        else
          Map.delete(data_triggers, data_trigger_key)
        end

      {:ok, %{state | data_triggers: next_data_triggers}}
    else
      {:ok, state}
    end
  end

  defp delete_volatile_trigger(
         state,
         {_obj_id, _obj_type},
         {{:device_trigger, proto_buf_device_trigger}, trigger_target}
       ) do
    event_type =
      EventTypeUtils.pretty_device_event_type(proto_buf_device_trigger.device_event_type)

    device_triggers = state.device_triggers

    updated_targets_list =
      Map.get(device_triggers, event_type, [])
      |> Enum.reject(fn target ->
        target == trigger_target
      end)

    updated_device_triggers = Map.put(device_triggers, event_type, updated_targets_list)

    {:ok, %{state | device_triggers: updated_device_triggers}}
  end

  def execute_time_based_actions(state, timestamp) do
    if state.connected && state.last_seen_message > 0 do
      # timestamps are handled as microseconds*10, so we need to divide by 10 when saving as a metric for a coherent data
      :telemetry.execute(
        [:astarte, :data_updater_plant, :service, :connected_devices],
        %{duration: Integer.floor_div(timestamp - state.last_seen_message, 10)},
        %{realm: state.realm, status: :ok}
      )
    end

    state
    |> Map.put(:last_seen_message, timestamp)
    |> TimeBasedActions.reload_groups_on_expiry(timestamp)
    |> TimeBasedActions.purge_expired_interfaces(timestamp)
    |> TimeBasedActions.reload_device_triggers_on_expiry(timestamp)
    |> TimeBasedActions.reload_device_deletion_status_on_expiry(timestamp)
    |> TimeBasedActions.reload_datastream_maximum_storage_retention_on_expiry(timestamp)
  end

  defp prune_device_properties(state, decoded_payload, timestamp) do
    {:ok, paths_set} =
      PayloadsDecoder.parse_device_properties_payload(decoded_payload, state.introspection)

    Enum.each(state.introspection, fn {interface, _} ->
      # TODO: check result here
      Core.Interface.prune_interface(state, interface, paths_set, timestamp)
    end)

    :ok
  end

  def set_device_disconnected(state, timestamp) do
    timestamp_ms = div(timestamp, 10_000)

    Queries.set_device_disconnected!(
      state.realm,
      state.device_id,
      DateTime.from_unix!(timestamp_ms, :millisecond),
      state.total_received_msgs,
      state.total_received_bytes,
      state.interface_exchanged_msgs,
      state.interface_exchanged_bytes
    )

    maybe_execute_device_disconnected_trigger(state, timestamp_ms)

    %{state | connected: false}
  end

  defp maybe_execute_device_disconnected_trigger(%State{connected: false}, _) do
    :ok
  end

  defp maybe_execute_device_disconnected_trigger(state, timestamp_ms) do
    trigger_target_with_policy_list =
      Map.get(state.device_triggers, :on_device_disconnection, [])
      |> Enum.map(fn target ->
        {target, Map.get(state.trigger_id_to_policy_name, target.parent_trigger_id)}
      end)

    device_id_string = Device.encode_device_id(state.device_id)

    TriggersHandler.device_disconnected(
      trigger_target_with_policy_list,
      state.realm,
      device_id_string,
      timestamp_ms
    )

    :telemetry.execute(
      [:astarte, :data_updater_plant, :data_updater, :device_disconnection],
      %{},
      %{realm: state.realm}
    )
  end

  defp ask_clean_session(state, timestamp) do
    Logger.warning("Disconnecting client and asking clean session.")
    %State{realm: realm, device_id: device_id} = state

    encoded_device_id = Device.encode_device_id(device_id)

    with :ok <- Queries.set_pending_empty_cache(realm, device_id, true),
         :ok <- force_disconnection(realm, encoded_device_id) do
      new_state = set_device_disconnected(state, timestamp)

      Logger.info("Successfully forced device disconnection.", tag: "forced_device_disconnection")

      :telemetry.execute(
        [:astarte, :data_updater_plant, :data_updater, :clean_session_request],
        %{},
        %{realm: new_state.realm}
      )

      {:ok, new_state}
    else
      {:error, reason} ->
        Logger.warning("Disconnect failed due to error: #{inspect(reason)}")
        # TODO: die gracefully here
        {:error, :clean_session_failed}
    end
  end

  defp force_disconnection(realm, encoded_device_id) do
    case VMQPlugin.disconnect("#{realm}/#{encoded_device_id}", true) do
      # Successfully disconnected
      :ok ->
        :ok

      # Not found means it was already disconnected, succeed anyway
      {:error, :not_found} ->
        :ok

      # Some other error, return it
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp can_write_on_interface?(interface_descriptor) do
    case interface_descriptor.ownership do
      :device ->
        :ok

      :server ->
        {:error, :cannot_write_on_server_owned_interface}
    end
  end

  defp reduce_interface_mapping(mappings, interface_descriptor, initial_acc, fun) do
    Enum.reduce(mappings, initial_acc, fn {_endpoint_id, mapping}, acc ->
      if mapping.interface_id == interface_descriptor.interface_id do
        fun.(mapping, acc)
      else
        acc
      end
    end)
  end

  defp send_control_consumer_properties(state) do
    Logger.debug("Device introspection: #{inspect(state.introspection)}.")

    abs_paths_list =
      Enum.flat_map(state.introspection, fn {interface, _} ->
        descriptor = Map.get(state.interfaces, interface)

        case Core.Interface.maybe_handle_cache_miss(descriptor, interface, state) do
          {:ok, interface_descriptor, new_state} ->
            gather_interface_property_paths(new_state.realm, interface_descriptor)

          {:error, :interface_loading_failed} ->
            Logger.warning("Failed #{interface} interface loading.")
            []
        end
      end)

    # TODO: use the returned byte count in stats
    with {:ok, _bytes} <-
           send_consumer_properties_payload(state.realm, state.device_id, abs_paths_list) do
      :ok
    end
  end

  defp gather_interface_property_paths(
         %State{device_id: device_id, mappings: mappings, realm: realm} = _state,
         %InterfaceDescriptor{type: :properties, ownership: :server} = interface_descriptor
       ) do
    reduce_interface_mapping(mappings, interface_descriptor, [], fn mapping, i_acc ->
      Queries.retrieve_property_values(realm, device_id, interface_descriptor, mapping)
      |> Enum.reduce(i_acc, fn %{path: path}, acc ->
        ["#{interface_descriptor.name}#{path}" | acc]
      end)
    end)
  end

  defp gather_interface_property_paths(_state, %InterfaceDescriptor{} = _descriptor) do
    []
  end

  defp resend_all_properties(state) do
    Logger.debug("Device introspection: #{inspect(state.introspection)}")

    Enum.reduce_while(state.introspection, {:ok, state}, fn {interface, _}, {:ok, state_acc} ->
      maybe_descriptor = Map.get(state_acc.interfaces, interface)

      with {:ok, interface_descriptor, new_state} <-
             Core.Interface.maybe_handle_cache_miss(maybe_descriptor, interface, state_acc),
           :ok <- resend_all_interface_properties(new_state, interface_descriptor) do
        {:cont, {:ok, new_state}}
      else
        {:error, :interface_loading_failed} ->
          Logger.warning("Failed #{interface} interface loading.")
          {:halt, {:error, :sending_properties_to_interface_failed}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp resend_all_interface_properties(
         %State{realm: realm, device_id: device_id, mappings: mappings} = _state,
         %InterfaceDescriptor{type: :properties, ownership: :server} = interface_descriptor
       ) do
    encoded_device_id = Device.encode_device_id(device_id)

    Core.Interface.each_interface_mapping(mappings, interface_descriptor, fn mapping ->
      %Mapping{value_type: value_type} = mapping

      column_name =
        CQLUtils.type_to_db_column_name(value_type) |> String.to_existing_atom()

      Queries.retrieve_property_values(realm, device_id, interface_descriptor, mapping)
      |> Enum.reduce_while(:ok, fn %{:path => path, ^column_name => value}, _acc ->
        case send_value(realm, encoded_device_id, interface_descriptor.name, path, value) do
          {:ok, _bytes} ->
            # TODO: use the returned bytes count in stats
            {:cont, :ok}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)
    end)
  end

  defp resend_all_interface_properties(_state, %InterfaceDescriptor{} = _descriptor) do
    :ok
  end

  defp send_consumer_properties_payload(realm, device_id, abs_paths_list) do
    topic = "#{realm}/#{Device.encode_device_id(device_id)}/control/consumer/properties"

    uncompressed_payload = Enum.join(abs_paths_list, ";")

    payload_size = byte_size(uncompressed_payload)
    compressed_payload = :zlib.compress(uncompressed_payload)

    payload = <<payload_size::unsigned-big-integer-size(32), compressed_payload::binary>>

    case VMQPlugin.publish(topic, payload, 2) do
      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote == 1 ->
        {:ok, byte_size(topic) + byte_size(payload)}

      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote > 1 ->
        # This should not happen so we print a warning, but we consider it a succesful publish
        Logger.warning(
          "Multiple match while publishing #{inspect(Base.encode64(payload))} on #{topic}.",
          tag: "publish_multiple_matches"
        )

        {:ok, byte_size(topic) + byte_size(payload)}

      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote == 0 ->
        {:error, :session_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp send_value(realm, device_id_string, interface_name, path, value) do
    topic = "#{realm}/#{device_id_string}/#{interface_name}#{path}"
    encapsulated_value = %{v: value}

    bson_value = Cyanide.encode!(encapsulated_value)

    Logger.debug("Going to publish #{inspect(encapsulated_value)} on #{topic}.")

    case VMQPlugin.publish(topic, bson_value, 2) do
      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote == 1 ->
        {:ok, byte_size(topic) + byte_size(bson_value)}

      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote > 1 ->
        # This should not happen so we print a warning, but we consider it a succesful publish
        Logger.warning(
          "Multiple match while publishing #{inspect(encapsulated_value)} on #{topic}.",
          tag: "publish_multiple_matches"
        )

        {:ok, byte_size(topic) + byte_size(bson_value)}

      {:ok, %{local_matches: local, remote_matches: remote}} when local + remote == 0 ->
        {:error, :session_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
