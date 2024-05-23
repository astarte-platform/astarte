#
# This file is part of Astarte.
#
# Copyright 2017 - 2023 SECO Mind Srl
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
  @behaviour Mississippi.Consumer.DataUpdater.Handler

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
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger, as: ProtobufDeviceTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils, as: SimpleTriggersProtobufUtils
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.DataAccess.Data
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Device, as: DeviceQueries
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Astarte.DataAccess.Mappings
  alias Astarte.DataUpdaterPlant.DataUpdater.Cache
  alias Astarte.DataUpdaterPlant.DataUpdater.CachedPath
  alias Astarte.DataUpdaterPlant.DataUpdater.EventTypeUtils
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.RPC.VMQPlugin
  alias Astarte.DataUpdaterPlant.TriggersHandler
  alias Astarte.DataUpdaterPlant.ValueMatchOperators
  alias Astarte.DataUpdaterPlant.TriggerPolicy.Queries, as: PolicyQueries
  require Logger

  @paths_cache_size 32
  @interface_lifespan_decimicroseconds 60 * 10 * 1000 * 10000
  @device_triggers_lifespan_decimicroseconds 60 * 10 * 1000 * 10000
  @groups_lifespan_decimicroseconds 60 * 10 * 1000 * 10000
  @deletion_refresh_lifespan_decimicroseconds 60 * 10 * 1000 * 10000
  @datastream_maximum_retention_refresh_lifespan_decimicroseconds 60 * 10 * 1000 * 10000

  use GenServer

  @impl true
  def init(sharding_key) do
    # TODO change this, we want extended device IDs to fall in the same process
    {realm, device_id} = sharding_key

    state = %State{
      realm: realm,
      device_id: device_id,
      connected: true,
      groups: [],
      interfaces: %{},
      interface_ids_to_name: %{},
      interfaces_by_expiry: [],
      mappings: %{},
      paths_cache: Cache.new(@paths_cache_size),
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

    {:ok, db_client} = Database.connect(realm: state.realm)

    stats_and_introspection =
      Queries.retrieve_device_stats_and_introspection!(db_client, device_id)

    {:ok, ttl} = Queries.fetch_datastream_maximum_storage_retention(db_client)

    new_state =
      Map.merge(state, stats_and_introspection)
      |> Map.put(:datastream_maximum_storage_retention, ttl)

    {:ok, new_state}
  end

  @impl true
  def handle_message(_, _, _, _, state) do
    # Ack all messages for now
    {:ack, :ok, state}
  end

  @impl true
  def handle_signal(_, state) do
    # All is ok for now
    {:ok, state}
  end

  @impl true
  def handle_continue(_, state) do
    # All is ok for now
    {:ok, state}
  end

  @impl true
  def terminate(_, state) do
    # All is ok for now
    {:ok, state}
  end

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
      paths_cache: Cache.new(@paths_cache_size),
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

    {:ok, db_client} = Database.connect(realm: new_state.realm)

    stats_and_introspection =
      Queries.retrieve_device_stats_and_introspection!(db_client, device_id)

    {:ok, ttl} = Queries.fetch_datastream_maximum_storage_retention(db_client)

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
    {:ok, db_client} = Database.connect(realm: state.realm)

    new_state = execute_time_based_actions(state, timestamp, db_client)

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
      db_client,
      new_state.device_id,
      timestamp_ms,
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
    {:ok, db_client} = Database.connect(realm: state.realm)

    new_state = execute_time_based_actions(state, timestamp, db_client)

    Queries.maybe_refresh_device_connected!(db_client, new_state.device_id)

    MessageTracker.ack_delivery(new_state.message_tracker, message_id)
    Logger.info("Device heartbeat.", tag: "device_heartbeat")

    %{new_state | connected: true, last_seen_message: timestamp}
  end

  def handle_internal(state, "/heartbeat", _payload, message_id, timestamp) do
    {:continue, handle_heartbeat(state, message_id, timestamp)}
  end

  def handle_internal(%State{discard_messages: true} = state, "/f", _, message_id, _) do
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(state.realm, Config.astarte_instance_id!())

    :ok = Queries.ack_end_device_deletion(keyspace_name, state.device_id)
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
    {:ok, db_client} = Database.connect(realm: state.realm)

    # Device deletion is among time-based actions
    new_state = execute_time_based_actions(state, timestamp, db_client)

    {:ok, new_state}
  end

  def handle_disconnection(state, message_id, timestamp) do
    {:ok, db_client} = Database.connect(realm: state.realm)

    new_state =
      state
      |> execute_time_based_actions(timestamp, db_client)
      |> set_device_disconnected(db_client, timestamp)

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
    get_on_data_triggers(state, :on_incoming_data, :any_interface, :any_endpoint)
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
    get_on_data_triggers(state, :on_incoming_data, interface_id, :any_endpoint)
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
    get_on_data_triggers(state, :on_incoming_data, interface_id, endpoint_id, path, value)
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
      get_on_data_triggers(state, :on_value_change, interface_id, endpoint_id, path, value)

    value_change_applied_triggers =
      get_on_data_triggers(
        state,
        :on_value_change_applied,
        interface_id,
        endpoint_id,
        path,
        value
      )

    path_created_triggers =
      get_on_data_triggers(state, :on_path_created, interface_id, endpoint_id, path, value)

    path_removed_triggers =
      get_on_data_triggers(state, :on_path_removed, interface_id, endpoint_id, path)

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
    {:ok, db_client} = Database.connect(realm: state.realm)

    new_state = execute_time_based_actions(state, timestamp, db_client)

    with :ok <- validate_interface(interface),
         :ok <- validate_path(path),
         maybe_descriptor <- Map.get(new_state.interfaces, interface),
         {:ok, interface_descriptor, new_state} <-
           maybe_handle_cache_miss(maybe_descriptor, interface, new_state, db_client),
         :ok <- can_write_on_interface?(interface_descriptor),
         interface_id <- interface_descriptor.interface_id,
         {:ok, endpoint} <- resolve_path(path, interface_descriptor, new_state.mappings),
         endpoint_id <- endpoint.endpoint_id,
         db_retention_policy = endpoint.database_retention_policy,
         db_ttl = endpoint.database_retention_ttl,
         {value, value_timestamp, _metadata} <-
           PayloadsDecoder.decode_bson_payload(payload, timestamp),
         expected_types <-
           extract_expected_types(path, interface_descriptor, endpoint, new_state.mappings),
         :ok <- validate_value_type(expected_types, value) do
      device_id_string = Device.encode_device_id(new_state.device_id)

      maybe_explicit_value_timestamp =
        if endpoint.explicit_timestamp do
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
                 endpoint,
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
                Queries.fetch_path_expiry(
                  db_client,
                  new_state.device_id,
                  interface_descriptor,
                  endpoint,
                  path
                ),
                db_max_ttl
              ) ->
                :ok

              true ->
                Queries.insert_path_into_db(
                  db_client,
                  new_state.device_id,
                  interface_descriptor,
                  endpoint,
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
          db_client,
          new_state.device_id,
          interface_descriptor,
          endpoint,
          path,
          value,
          maybe_explicit_value_timestamp,
          timestamp,
          ttl: db_max_ttl
        )

      :ok = insert_result

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

  defp extract_expected_types(_path, interface_descriptor, endpoint, mappings) do
    case interface_descriptor.aggregation do
      :individual ->
        endpoint.value_type

      :object ->
        # TODO: we should probably cache this
        Enum.flat_map(mappings, fn {_id, mapping} ->
          if mapping.interface_id == interface_descriptor.interface_id do
            expected_key =
              mapping.endpoint
              |> String.split("/")
              |> List.last()

            [{expected_key, mapping.value_type}]
          else
            []
          end
        end)
        |> Enum.into(%{})
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
      process_introspection(state, new_introspection_list, payload, message_id, timestamp)
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

  def process_introspection(state, new_introspection_list, payload, message_id, timestamp) do
    {:ok, db_client} = Database.connect(realm: state.realm)

    new_state = execute_time_based_actions(state, timestamp, db_client)

    timestamp_ms = div(timestamp, 10_000)

    {db_introspection_map, db_introspection_minor_map} =
      List.foldl(new_introspection_list, {%{}, %{}}, fn {interface, major, minor},
                                                        {introspection_map,
                                                         introspection_minor_map} ->
        introspection_map = Map.put(introspection_map, interface, major)
        introspection_minor_map = Map.put(introspection_minor_map, interface, minor)

        {introspection_map, introspection_minor_map}
      end)

    any_interface_id = SimpleTriggersProtobufUtils.any_interface_object_id()

    %{device_triggers: device_triggers} =
      populate_triggers_for_object!(new_state, db_client, any_interface_id, :any_interface)

    realm = new_state.realm
    device_id_string = Device.encode_device_id(new_state.device_id)

    on_introspection_target_with_policy_list =
      Map.get(device_triggers, :on_incoming_introspection, [])
      |> Enum.map(fn target ->
        {target, Map.get(state.trigger_id_to_policy_name, target.parent_trigger_id)}
      end)

    TriggersHandler.incoming_introspection(
      on_introspection_target_with_policy_list,
      realm,
      device_id_string,
      payload,
      timestamp_ms
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
          Logger.debug("Adding interfaces to introspection: #{inspect(changed_interfaces)}.")

          Enum.each(changed_interfaces, fn {interface_name, interface_major} ->
            :ok =
              if interface_major == 0 do
                Queries.register_device_with_interface(
                  db_client,
                  state.device_id,
                  interface_name,
                  0
                )
              else
                :ok
              end

            minor = Map.get(db_introspection_minor_map, interface_name)

            interface_added_target_with_policy_list =
              (Map.get(
                 device_triggers,
                 {:on_interface_added, CQLUtils.interface_id(interface_name, interface_major)},
                 []
               ) ++
                 Map.get(device_triggers, {:on_interface_added, :any_interface}, []))
              |> Enum.map(fn target ->
                {target, Map.get(state.trigger_id_to_policy_name, target.parent_trigger_id)}
              end)

            TriggersHandler.interface_added(
              interface_added_target_with_policy_list,
              realm,
              device_id_string,
              interface_name,
              interface_major,
              minor,
              timestamp_ms
            )
          end)

        :del ->
          Logger.debug("Removing interfaces from introspection: #{inspect(changed_interfaces)}.")

          Enum.each(changed_interfaces, fn {interface_name, interface_major} ->
            :ok =
              if interface_major == 0 do
                Queries.unregister_device_with_interface(
                  db_client,
                  state.device_id,
                  interface_name,
                  0
                )
              else
                :ok
              end

            interface_removed_target_with_policy_list =
              (Map.get(
                 device_triggers,
                 {:on_interface_removed, CQLUtils.interface_id(interface_name, interface_major)},
                 []
               ) ++
                 Map.get(device_triggers, {:on_interface_removed, :any_interface}, []))
              |> Enum.map(fn target ->
                {target, Map.get(state.trigger_id_to_policy_name, target.parent_trigger_id)}
              end)

            TriggersHandler.interface_removed(
              interface_removed_target_with_policy_list,
              realm,
              device_id_string,
              interface_name,
              interface_major,
              timestamp_ms
            )
          end)

        :eq ->
          Logger.debug("#{inspect(changed_interfaces)} are already on device introspection.")
      end
    end)

    {added_interfaces, removed_interfaces} =
      Enum.reduce(diff, {%{}, %{}}, fn {change_type, changed_interfaces}, {add_acc, rm_acc} ->
        case change_type do
          :ins ->
            changed_map = Enum.into(changed_interfaces, %{})
            {Map.merge(add_acc, changed_map), rm_acc}

          :del ->
            changed_map = Enum.into(changed_interfaces, %{})
            {add_acc, Map.merge(rm_acc, changed_map)}

          :eq ->
            {add_acc, rm_acc}
        end
      end)

    {:ok, old_minors} = Queries.fetch_device_introspection_minors(db_client, state.device_id)

    readded_introspection = Enum.to_list(added_interfaces)

    old_introspection =
      Enum.reduce(removed_interfaces, %{}, fn {iface, _major}, acc ->
        prev_major = Map.fetch!(state.introspection, iface)
        prev_minor = Map.get(old_minors, iface, 0)
        Map.put(acc, {iface, prev_major}, prev_minor)
      end)

    :ok = Queries.add_old_interfaces(db_client, new_state.device_id, old_introspection)
    :ok = Queries.remove_old_interfaces(db_client, new_state.device_id, readded_introspection)

    # Deliver interface_minor_updated triggers if needed
    for {interface_name, old_minor} <- old_minors,
        interface_major = Map.fetch!(state.introspection, interface_name),
        Map.get(db_introspection_map, interface_name) == interface_major,
        new_minor = Map.get(db_introspection_minor_map, interface_name),
        new_minor != old_minor do
      interface_id = CQLUtils.interface_id(interface_name, interface_major)

      interface_minor_updated_target_with_policy_list =
        Map.get(device_triggers, {:on_interface_minor_updated, interface_id}, [])
        |> Enum.map(fn target ->
          {target, Map.get(state.trigger_id_to_policy_name, target.parent_trigger_id)}
        end)

      TriggersHandler.interface_minor_updated(
        interface_minor_updated_target_with_policy_list,
        realm,
        device_id_string,
        interface_name,
        interface_major,
        old_minor,
        new_minor,
        timestamp_ms
      )
    end

    # Removed/updated interfaces must be purged away, otherwise data will be written using old
    # interface_id.
    remove_interfaces_list = Map.keys(removed_interfaces)

    {interfaces_to_drop_map, _} = Map.split(new_state.interfaces, remove_interfaces_list)
    interfaces_to_drop_list = Map.keys(interfaces_to_drop_map)

    # Forget interfaces wants a list of already loaded interfaces, otherwise it will crash
    new_state = forget_interfaces(new_state, interfaces_to_drop_list)

    Queries.update_device_introspection!(
      db_client,
      new_state.device_id,
      db_introspection_map,
      db_introspection_minor_map
    )

    MessageTracker.ack_delivery(new_state.message_tracker, message_id)

    :telemetry.execute(
      [:astarte, :data_updater_plant, :data_updater, :processed_introspection],
      %{},
      %{realm: realm}
    )

    %{
      new_state
      | introspection: db_introspection_map,
        paths_cache: Cache.new(@paths_cache_size),
        total_received_msgs: new_state.total_received_msgs + 1,
        total_received_bytes: new_state.total_received_bytes + byte_size(payload)
    }
  end

  def handle_control(%State{discard_messages: true} = state, _, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_control(state, "/producer/properties", <<0, 0, 0, 0>>, message_id, timestamp) do
    {:ok, db_client} = Database.connect(realm: state.realm)

    new_state = execute_time_based_actions(state, timestamp, db_client)

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
    {:ok, db_client} = Database.connect(realm: state.realm)

    new_state = execute_time_based_actions(state, timestamp, db_client)

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
    {:ok, db_client} = Database.connect(realm: state.realm)

    new_state = execute_time_based_actions(state, timestamp, db_client)

    with :ok <- send_control_consumer_properties(state, db_client),
         {:ok, new_state} <- resend_all_properties(state, db_client),
         :ok <- Queries.set_pending_empty_cache(db_client, new_state.device_id, false) do
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
          {:ok, load_trigger(new_state, trigger, target)}

        {:data_trigger, %ProtobufDataTrigger{match_path: match_path}} ->
          with {:ok, _endpoint_id} <- EndpointsAutomaton.resolve_path(match_path, automaton) do
            {:ok, load_trigger(new_state, trigger, target)}
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
          {:ok, load_trigger(new_state, trigger, target)}

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
          {:ok, load_trigger(new_state, trigger, target)}
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

      data_trigger_key = data_trigger_to_key(state, data_trigger_to_be_deleted, event_type)
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

  defp reload_groups_on_expiry(state, timestamp, db_client) do
    if state.last_groups_refresh + @groups_lifespan_decimicroseconds <= timestamp do
      {:ok, groups} = Queries.get_device_groups(db_client, state.device_id)

      %{state | last_groups_refresh: timestamp, groups: groups}
    else
      state
    end
  end

  defp reload_device_triggers_on_expiry(state, timestamp, db_client) do
    if state.last_device_triggers_refresh + @device_triggers_lifespan_decimicroseconds <=
         timestamp do
      any_device_id = SimpleTriggersProtobufUtils.any_device_object_id()

      any_interface_id = SimpleTriggersProtobufUtils.any_interface_object_id()

      device_and_any_interface_object_id =
        SimpleTriggersProtobufUtils.get_device_and_any_interface_object_id(state.device_id)

      # TODO when introspection triggers are supported, we should also forget any_interface
      # introspection triggers here, or handle them separately

      state
      |> Map.put(:last_device_triggers_refresh, timestamp)
      |> Map.put(:device_triggers, %{})
      |> forget_any_interface_data_triggers()
      |> populate_triggers_for_object!(db_client, any_device_id, :any_device)
      |> populate_triggers_for_object!(db_client, state.device_id, :device)
      |> populate_triggers_for_object!(db_client, any_interface_id, :any_interface)
      |> populate_triggers_for_object!(
        db_client,
        device_and_any_interface_object_id,
        :device_and_any_interface
      )
      |> populate_group_device_triggers!(db_client)
      |> populate_group_and_any_interface_triggers!(db_client)
    else
      state
    end
  end

  defp populate_group_device_triggers!(state, db_client) do
    Enum.map(state.groups, &SimpleTriggersProtobufUtils.get_group_object_id/1)
    |> Enum.reduce(state, &populate_triggers_for_object!(&2, db_client, &1, :group))
  end

  defp populate_group_and_any_interface_triggers!(state, db_client) do
    Enum.map(state.groups, &SimpleTriggersProtobufUtils.get_group_and_any_interface_object_id/1)
    |> Enum.reduce(
      state,
      &populate_triggers_for_object!(&2, db_client, &1, :group_and_any_interface)
    )
  end

  defp execute_time_based_actions(state, timestamp, db_client) do
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
    |> reload_groups_on_expiry(timestamp, db_client)
    |> purge_expired_interfaces(timestamp)
    |> reload_device_triggers_on_expiry(timestamp, db_client)
    |> reload_device_deletion_status_on_expiry(timestamp, db_client)
    |> reload_datastream_maximum_storage_retention_on_expiry(timestamp, db_client)
  end

  defp reload_device_deletion_status_on_expiry(state, timestamp, db_client) do
    if state.last_deletion_in_progress_refresh + @deletion_refresh_lifespan_decimicroseconds <=
         timestamp do
      new_state = maybe_start_device_deletion(db_client, state, timestamp)
      %State{new_state | last_deletion_in_progress_refresh: timestamp}
    else
      state
    end
  end

  defp reload_datastream_maximum_storage_retention_on_expiry(state, timestamp, db_client) do
    if state.last_datastream_maximum_retention_refresh +
         @datastream_maximum_retention_refresh_lifespan_decimicroseconds <=
         timestamp do
      case Queries.fetch_datastream_maximum_storage_retention(db_client) do
        {:ok, ttl} ->
          %State{
            state
            | datastream_maximum_storage_retention: ttl,
              last_datastream_maximum_retention_refresh: timestamp
          }

        {:error, _reason} ->
          _ =
            Logger.warning(
              "Failed to load last_datastream_maximum_retention_refresh, keeping old one",
              tag: "last_datastream_maximum_retention_refresh_fail"
            )

          state
      end
    else
      state
    end
  end

  defp maybe_start_device_deletion(db_client, state, timestamp) do
    if should_start_device_deletion?(state.realm, state.device_id) do
      encoded_device_id = Device.encode_device_id(state.device_id)

      :ok = force_device_deletion_from_broker(state.realm, encoded_device_id)
      new_state = set_device_disconnected(state, db_client, timestamp)

      _ =
        Logger.info("Stop handling data from device in deletion, device_id #{encoded_device_id}")

      # It's ok to repeat that, as we always write ⊤
      keyspace_name =
        CQLUtils.realm_name_to_keyspace_name(state.realm, Config.astarte_instance_id!())

      Queries.ack_start_device_deletion(keyspace_name, state.device_id)

      %State{new_state | discard_messages: true}
    else
      state
    end
  end

  defp should_start_device_deletion?(realm_name, device_id) do
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    case Queries.check_device_deletion_in_progress(keyspace_name, device_id) do
      {:ok, true} ->
        true

      {:ok, false} ->
        false

      {:error, reason} ->
        _ =
          Logger.warning(
            "Cannot check device deletion status for #{inspect(device_id)}, reason #{inspect(reason)}",
            tag: "should_start_device_deletion_fail"
          )

        false
    end
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

  defp forget_any_interface_data_triggers(state) do
    updated_data_triggers =
      for {{_type, iface_id, _endpoint} = key, value} <- state.data_triggers,
          iface_id != :any_interface,
          into: %{} do
        {key, value}
      end

    %{state | data_triggers: updated_data_triggers}
  end

  defp forget_interfaces(state, []) do
    state
  end

  defp forget_interfaces(state, interfaces_to_drop) do
    iface_ids_to_drop =
      Enum.filter(interfaces_to_drop, &Map.has_key?(state.interfaces, &1))
      |> Enum.map(fn iface ->
        Map.fetch!(state.interfaces, iface).interface_id
      end)

    updated_triggers =
      Enum.reduce(iface_ids_to_drop, state.data_triggers, fn interface_id, data_triggers ->
        Enum.reject(data_triggers, fn {{_event_type, iface_id, _endpoint}, _val} ->
          iface_id == interface_id
        end)
        |> Enum.into(%{})
      end)

    updated_mappings =
      Enum.reduce(iface_ids_to_drop, state.mappings, fn interface_id, mappings ->
        Enum.reject(mappings, fn {_endpoint_id, mapping} ->
          mapping.interface_id == interface_id
        end)
        |> Enum.into(%{})
      end)

    updated_ids =
      Enum.reduce(iface_ids_to_drop, state.interface_ids_to_name, fn interface_id, ids ->
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
    with {:ok, major_version} <-
           DeviceQueries.interface_version(state.realm, state.device_id, interface_name),
         {:ok, interface_row} <-
           InterfaceQueries.retrieve_interface_row(state.realm, interface_name, major_version),
         %InterfaceDescriptor{interface_id: interface_id} = interface_descriptor <-
           InterfaceDescriptor.from_db_result!(interface_row),
         {:ok, mappings} <-
           Mappings.fetch_interface_mappings_map(state.realm, interface_id),
         new_interfaces_by_expiry <-
           state.interfaces_by_expiry ++
             [{state.last_seen_message + @interface_lifespan_decimicroseconds, interface_name}],
         new_state <- %State{
           state
           | interfaces: Map.put(state.interfaces, interface_name, interface_descriptor),
             interface_ids_to_name:
               Map.put(
                 state.interface_ids_to_name,
                 interface_id,
                 interface_name
               ),
             interfaces_by_expiry: new_interfaces_by_expiry,
             mappings: Map.merge(state.mappings, mappings)
         },
         new_state <-
           populate_triggers_for_object!(
             new_state,
             db_client,
             interface_descriptor.interface_id,
             :interface
           ),
         device_and_interface_object_id =
           SimpleTriggersProtobufUtils.get_device_and_interface_object_id(
             state.device_id,
             interface_id
           ),
         new_state =
           populate_triggers_for_object!(
             new_state,
             db_client,
             device_and_interface_object_id,
             :device_and_interface
           ),
         new_state =
           populate_triggers_for_group_and_interface!(
             new_state,
             db_client,
             interface_id
           ) do
      # TODO: make everything with-friendly
      {:ok, interface_descriptor, new_state}
    else
      # Known errors. TODO: handle specific cases (e.g. ask for new introspection etc.)
      {:error, :interface_not_in_introspection} ->
        {:error, :interface_loading_failed}

      {:error, :device_not_found} ->
        {:error, :interface_loading_failed}

      {:error, :database_error} ->
        {:error, :interface_loading_failed}

      {:error, :interface_not_found} ->
        {:error, :interface_loading_failed}

      other ->
        Logger.warning("maybe_handle_cache_miss failed: #{inspect(other)}")
        {:error, :interface_loading_failed}
    end
  end

  defp maybe_handle_cache_miss(interface_descriptor, _interface_name, state, _db_client) do
    {:ok, interface_descriptor, state}
  end

  defp populate_triggers_for_group_and_interface!(state, db_client, interface_id) do
    Enum.map(
      state.groups,
      &SimpleTriggersProtobufUtils.get_group_and_interface_object_id(&1, interface_id)
    )
    |> Enum.reduce(
      state,
      &populate_triggers_for_object!(&2, db_client, &1, :group_and_interface)
    )
  end

  defp prune_device_properties(state, decoded_payload, timestamp) do
    {:ok, paths_set} =
      PayloadsDecoder.parse_device_properties_payload(decoded_payload, state.introspection)

    {:ok, db_client} = Database.connect(realm: state.realm)

    Enum.each(state.introspection, fn {interface, _} ->
      # TODO: check result here
      prune_interface(state, db_client, interface, paths_set, timestamp)
    end)

    :ok
  end

  defp prune_interface(state, db_client, interface, all_paths_set, timestamp) do
    with {:ok, interface_descriptor, new_state} <-
           maybe_handle_cache_miss(
             Map.get(state.interfaces, interface),
             interface,
             state,
             db_client
           ) do
      cond do
        interface_descriptor.type != :properties ->
          # TODO: nobody uses new_state
          {:ok, new_state}

        interface_descriptor.ownership != :device ->
          Logger.warning("Tried to prune server owned interface: #{interface}.")
          {:error, :maybe_outdated_introspection}

        true ->
          do_prune(new_state, db_client, interface_descriptor, all_paths_set, timestamp)
          # TODO: nobody uses new_state
          {:ok, new_state}
      end
    end
  end

  defp do_prune(state, db, interface_descriptor, all_paths_set, timestamp) do
    each_interface_mapping(state.mappings, interface_descriptor, fn mapping ->
      endpoint_id = mapping.endpoint_id

      Queries.query_all_endpoint_paths!(db, state.device_id, interface_descriptor, endpoint_id)
      |> Enum.each(fn path_row ->
        path = path_row[:path]

        if not MapSet.member?(all_paths_set, {interface_descriptor.name, path}) do
          device_id_string = Device.encode_device_id(state.device_id)

          {:ok, endpoint_id} =
            EndpointsAutomaton.resolve_path(path, interface_descriptor.automaton)

          Queries.delete_property_from_db(state, db, interface_descriptor, endpoint_id, path)

          interface_id = interface_descriptor.interface_id

          path_removed_triggers =
            get_on_data_triggers(state, :on_path_removed, interface_id, endpoint_id, path)

          i_name = interface_descriptor.name

          Enum.each(path_removed_triggers, fn trigger ->
            target_with_policy_list =
              trigger.trigger_targets
              |> Enum.map(fn target ->
                {target, Map.get(state.trigger_id_to_policy_name, target.parent_trigger_id)}
              end)

            TriggersHandler.path_removed(
              target_with_policy_list,
              state.realm,
              device_id_string,
              i_name,
              path,
              timestamp
            )
          end)
        end
      end)
    end)
  end

  defp set_device_disconnected(state, db_client, timestamp) do
    timestamp_ms = div(timestamp, 10_000)

    Queries.set_device_disconnected!(
      db_client,
      state.device_id,
      timestamp_ms,
      state.total_received_msgs,
      state.total_received_bytes,
      state.interface_exchanged_msgs,
      state.interface_exchanged_bytes
    )

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

    %{state | connected: false}
  end

  defp ask_clean_session(
         %State{realm: realm, device_id: device_id} = state,
         timestamp
       ) do
    Logger.warning("Disconnecting client and asking clean session.")

    encoded_device_id = Device.encode_device_id(device_id)

    {:ok, db_client} = Database.connect(realm: state.realm)

    with :ok <- Queries.set_pending_empty_cache(db_client, device_id, true),
         :ok <- force_disconnection(realm, encoded_device_id) do
      new_state = set_device_disconnected(state, db_client, timestamp)

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

  defp force_device_deletion_from_broker(realm, encoded_device_id) do
    _ = Logger.info("Disconnecting device to be deleted, device_id #{encoded_device_id}")

    case VMQPlugin.delete(realm, encoded_device_id) do
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

  defp get_on_data_triggers(state, event, interface_id, endpoint_id) do
    key = {event, interface_id, endpoint_id}

    Map.get(state.data_triggers, key, [])
  end

  defp get_on_data_triggers(state, event, interface_id, endpoint_id, path, value \\ nil) do
    key = {event, interface_id, endpoint_id}

    candidate_triggers = Map.get(state.data_triggers, key, nil)

    if candidate_triggers do
      ["" | path_tokens] = String.split(path, "/")

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
    object_type_int = SimpleTriggersProtobufUtils.object_type_to_int!(object_type)

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

  defp data_trigger_to_key(state, data_trigger, event_type) do
    %DataTrigger{
      path_match_tokens: path_match_tokens,
      interface_id: interface_id
    } = data_trigger

    endpoint =
      if path_match_tokens != :any_endpoint and interface_id != :any_interface do
        %InterfaceDescriptor{automaton: automaton} =
          Map.get(state.interfaces, Map.get(state.interface_ids_to_name, interface_id))

        path_no_root =
          path_match_tokens
          |> Enum.map(&replace_empty_token/1)
          |> Enum.join("/")

        {:ok, endpoint_id} = EndpointsAutomaton.resolve_path("/#{path_no_root}", automaton)

        endpoint_id
      else
        :any_endpoint
      end

    {event_type, interface_id, endpoint}
  end

  defp replace_empty_token(token) do
    case token do
      "" ->
        "%{}"

      not_empty ->
        not_empty
    end
  end

  defp load_trigger(state, {:data_trigger, proto_buf_data_trigger}, trigger_target) do
    new_data_trigger =
      SimpleTriggersProtobufUtils.simple_trigger_to_data_trigger(proto_buf_data_trigger)

    data_triggers = state.data_triggers

    event_type = EventTypeUtils.pretty_data_trigger_type(proto_buf_data_trigger.data_trigger_type)
    data_trigger_key = data_trigger_to_key(state, new_data_trigger, event_type)
    existing_triggers_for_key = Map.get(data_triggers, data_trigger_key, [])

    # Extract all the targets belonging to the (eventual) existing congruent trigger
    congruent_targets =
      existing_triggers_for_key
      |> Enum.filter(&DataTrigger.are_congruent?(&1, new_data_trigger))
      |> Enum.flat_map(fn congruent_trigger -> congruent_trigger.trigger_targets end)

    new_targets = [trigger_target | congruent_targets]
    new_data_trigger_with_targets = %{new_data_trigger | trigger_targets: new_targets}

    # Register the new target
    :ok = TriggersHandler.register_target(trigger_target)

    # Replace the (eventual) congruent existing trigger with the new one
    new_data_triggers_for_key = [
      new_data_trigger_with_targets
      | Enum.reject(
          existing_triggers_for_key,
          &DataTrigger.are_congruent?(&1, new_data_trigger_with_targets)
        )
    ]

    next_data_triggers = Map.put(data_triggers, data_trigger_key, new_data_triggers_for_key)

    Map.put(state, :data_triggers, next_data_triggers)
    |> maybe_cache_trigger_policy(trigger_target)
  end

  # TODO: implement on_empty_cache_received
  defp load_trigger(state, {:device_trigger, proto_buf_device_trigger}, trigger_target) do
    device_triggers = state.device_triggers

    # device event type is one of
    # :on_device_connected, :on_device_disconnected, :on_device_empty_cache_received, :on_device_error,
    # :on_incoming_introspection, :on_interface_added, :on_interface_removed, :on_interface_minor_updated
    event_type =
      EventTypeUtils.pretty_device_event_type(proto_buf_device_trigger.device_event_type)

    # introspection triggers have a pair as key, standard device ones do not
    trigger_key = device_trigger_to_key(event_type, proto_buf_device_trigger)

    existing_trigger_targets = Map.get(device_triggers, trigger_key, [])

    new_targets = [trigger_target | existing_trigger_targets]

    # Register the new target
    :ok = TriggersHandler.register_target(trigger_target)

    next_device_triggers = Map.put(device_triggers, trigger_key, new_targets)
    # Map.put(state, :introspection_triggers, next_introspection_triggers)
    Map.put(state, :device_triggers, next_device_triggers)
    |> maybe_cache_trigger_policy(trigger_target)
  end

  defp device_trigger_to_key(event_type, proto_buf_device_trigger) do
    case event_type do
      :on_interface_added ->
        {event_type, introspection_trigger_interface(proto_buf_device_trigger)}

      :on_interface_removed ->
        {event_type, introspection_trigger_interface(proto_buf_device_trigger)}

      :on_interface_minor_updated ->
        {event_type, introspection_trigger_interface(proto_buf_device_trigger)}

      # other device triggers do not care about interfaces
      _ ->
        event_type
    end
  end

  defp introspection_trigger_interface(%ProtobufDeviceTrigger{
         interface_name: interface_name,
         interface_major: interface_major
       }) do
    SimpleTriggersProtobufUtils.get_interface_id_or_any(interface_name, interface_major)
  end

  # TODO: consider what we should to with the cached policy if/when we allow updating a policy
  defp maybe_cache_trigger_policy(state, %AMQPTriggerTarget{parent_trigger_id: parent_trigger_id}) do
    %State{realm: realm_name, trigger_id_to_policy_name: trigger_id_to_policy_name} = state

    case PolicyQueries.retrieve_policy_name(
           realm_name,
           parent_trigger_id
         ) do
      {:ok, policy_name} ->
        next_trigger_id_to_policy_name =
          Map.put(trigger_id_to_policy_name, parent_trigger_id, policy_name)

        %{state | trigger_id_to_policy_name: next_trigger_id_to_policy_name}

      # @default policy is not installed, so here are triggers without policy
      {:error, :policy_not_found} ->
        state
    end
  end

  defp resolve_path(path, interface_descriptor, mappings) do
    case interface_descriptor.aggregation do
      :individual ->
        with {:ok, endpoint_id} <-
               EndpointsAutomaton.resolve_path(path, interface_descriptor.automaton),
             {:ok, endpoint} <- Map.fetch(mappings, endpoint_id) do
          {:ok, endpoint}
        else
          :error ->
            # Map.fetch failed
            Logger.warning(
              "endpoint_id for path #{inspect(path)} not found in mappings #{inspect(mappings)}."
            )

            {:error, :mapping_not_found}

          {:error, reason} ->
            Logger.warning(
              "EndpointsAutomaton.resolve_path failed with reason #{inspect(reason)}."
            )

            {:error, :mapping_not_found}

          {:guessed, guessed_endpoints} ->
            {:guessed, guessed_endpoints}
        end

      :object ->
        with {:guessed, [first_endpoint_id | _tail] = guessed_endpoints} <-
               EndpointsAutomaton.resolve_path(path, interface_descriptor.automaton),
             :ok <- check_object_aggregation_prefix(path, guessed_endpoints, mappings),
             {:ok, first_mapping} <- Map.fetch(mappings, first_endpoint_id) do
          # We return the first guessed mapping changing just its endpoint id, using the canonical
          # endpoint id used in object aggregated interfaces. This way all mapping properties
          # (database_retention_ttl, reliability etc) are correctly set since they're the same in
          # all mappings (this is enforced by Realm Management when the interface is installed)

          endpoint_id =
            CQLUtils.endpoint_id(
              interface_descriptor.name,
              interface_descriptor.major_version,
              ""
            )

          {:ok, %{first_mapping | endpoint_id: endpoint_id}}
        else
          {:ok, _endpoint_id} ->
            # This is invalid here, publish doesn't happen on endpoints in object aggregated interfaces
            Logger.warning(
              "Tried to publish on endpoint #{inspect(path)} for object aggregated " <>
                "interface #{inspect(interface_descriptor.name)}. You should publish on " <>
                "the common prefix",
              tag: "invalid_path"
            )

            {:error, :mapping_not_found}

          {:error, :not_found} ->
            Logger.warning(
              "Tried to publish on invalid path #{inspect(path)} for object aggregated " <>
                "interface #{inspect(interface_descriptor.name)}",
              tag: "invalid_path"
            )

            {:error, :mapping_not_found}

          {:error, :invalid_object_aggregation_path} ->
            Logger.warning(
              "Tried to publish on invalid path #{inspect(path)} for object aggregated " <>
                "interface #{inspect(interface_descriptor.name)}",
              tag: "invalid_path"
            )

            {:error, :mapping_not_found}
        end
    end
  end

  defp check_object_aggregation_prefix(path, guessed_endpoints, mappings) do
    received_path_depth = path_or_endpoint_depth(path)

    Enum.reduce_while(guessed_endpoints, :ok, fn
      endpoint_id, _acc ->
        with {:ok, %Mapping{endpoint: endpoint}} <- Map.fetch(mappings, endpoint_id),
             endpoint_depth when received_path_depth == endpoint_depth - 1 <-
               path_or_endpoint_depth(endpoint) do
          {:cont, :ok}
        else
          _ ->
            {:halt, {:error, :invalid_object_aggregation_path}}
        end
    end)
  end

  defp path_or_endpoint_depth(path) when is_binary(path) do
    String.split(path, "/", trim: true)
    |> length()
  end

  defp can_write_on_interface?(interface_descriptor) do
    case interface_descriptor.ownership do
      :device ->
        :ok

      :server ->
        {:error, :cannot_write_on_server_owned_interface}
    end
  end

  defp each_interface_mapping(mappings, interface_descriptor, fun) do
    Enum.each(mappings, fn {_endpoint_id, mapping} ->
      if mapping.interface_id == interface_descriptor.interface_id do
        fun.(mapping)
      end
    end)
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

  defp send_control_consumer_properties(state, db_client) do
    Logger.debug("Device introspection: #{inspect(state.introspection)}.")

    abs_paths_list =
      Enum.flat_map(state.introspection, fn {interface, _} ->
        descriptor = Map.get(state.interfaces, interface)

        case maybe_handle_cache_miss(descriptor, interface, state, db_client) do
          {:ok, interface_descriptor, new_state} ->
            gather_interface_properties(new_state, db_client, interface_descriptor)

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

  defp gather_interface_properties(
         %State{device_id: device_id, mappings: mappings} = _state,
         db_client,
         %InterfaceDescriptor{type: :properties, ownership: :server} = interface_descriptor
       ) do
    reduce_interface_mapping(mappings, interface_descriptor, [], fn mapping, i_acc ->
      Queries.retrieve_endpoint_values(db_client, device_id, interface_descriptor, mapping)
      |> Enum.reduce(i_acc, fn [{:path, path}, {_, _value}], acc ->
        ["#{interface_descriptor.name}#{path}" | acc]
      end)
    end)
  end

  defp gather_interface_properties(_state, _db, %InterfaceDescriptor{} = _descriptor) do
    []
  end

  defp resend_all_properties(state, db_client) do
    Logger.debug("Device introspection: #{inspect(state.introspection)}")

    Enum.reduce_while(state.introspection, {:ok, state}, fn {interface, _}, {:ok, state_acc} ->
      maybe_descriptor = Map.get(state_acc.interfaces, interface)

      with {:ok, interface_descriptor, new_state} <-
             maybe_handle_cache_miss(maybe_descriptor, interface, state_acc, db_client),
           :ok <- resend_all_interface_properties(new_state, db_client, interface_descriptor) do
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
         db_client,
         %InterfaceDescriptor{type: :properties, ownership: :server} = interface_descriptor
       ) do
    encoded_device_id = Device.encode_device_id(device_id)

    each_interface_mapping(mappings, interface_descriptor, fn mapping ->
      Queries.retrieve_endpoint_values(db_client, device_id, interface_descriptor, mapping)
      |> Enum.reduce_while(:ok, fn [{:path, path}, {_, value}], _acc ->
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

  defp resend_all_interface_properties(_state, _db, %InterfaceDescriptor{} = _descriptor) do
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
