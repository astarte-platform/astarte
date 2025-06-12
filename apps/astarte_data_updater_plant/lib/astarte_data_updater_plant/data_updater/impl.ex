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

  alias Astarte.DataUpdaterPlant.DataUpdater.State

  alias Astarte.DataUpdaterPlant.DataUpdater.Cache

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
    {:ok, ttl} = Queries.get_datastream_maximum_storage_retention(new_state.realm)

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
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

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

  def handle_internal(state, path, payload, message_id, timestamp) do
    Core.InternalHandler.handle_internal(state, path, payload, message_id, timestamp)
  end

  def start_device_deletion(state, timestamp) do
    # Device deletion is among time-based actions
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    {:ok, new_state}
  end

  def handle_disconnection(state, message_id, timestamp) do
    new_state =
      state
      |> TimeBasedActions.execute_time_based_actions(timestamp)
      |> Core.Device.set_device_disconnected(timestamp)

    MessageTracker.ack_delivery(new_state.message_tracker, message_id)
    Logger.info("Device disconnected.", tag: "device_disconnected")

    %{new_state | last_seen_message: timestamp}
  end

  def handle_data(%State{discard_messages: true} = state, _, _, _, message_id, _) do
    MessageTracker.discard(state.message_tracker, message_id)
    state
  end

  def handle_data(state, interface, path, payload, message_id, timestamp) do
    TimeBasedActions.execute_time_based_actions(state, timestamp)
    |> Core.DataHandler.handle_data(interface, path, payload, message_id, timestamp)
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

        {:ok, new_state} = Core.Device.ask_clean_session(state, timestamp)
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

        Core.Trigger.execute_device_error_triggers(
          new_state,
          "invalid_introspection",
          error_metadata,
          timestamp
        )

        Core.DataHandler.update_stats(new_state, "", nil, "", payload)
    end
  end

  defdelegate handle_control(state, path, payload, message_id, timestamp), to: Core.ControlHandler

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

  def ask_clean_session(state, timestamp) do
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
