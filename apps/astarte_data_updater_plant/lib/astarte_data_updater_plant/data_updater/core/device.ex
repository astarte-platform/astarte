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
#
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.Device do
  @moduledoc """
  Core part of the data_updater message processing.

  This module contains functions and utilities to process devices.
  """
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.DataUpdaterPlant.TimeBasedActions
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.DataUpdater.Cache
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.PayloadsDecoder
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.DataUpdaterPlant.RPC.VMQPlugin
  alias Astarte.Core.CQLUtils
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.TriggersHandler
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf

  require Logger

  def process_introspection(state, new_introspection_list, payload, message_id, timestamp) do
    new_state = TimeBasedActions.execute_time_based_actions(state, timestamp)

    timestamp_ms = div(timestamp, 10_000)

    {db_introspection_map, db_introspection_minor_map} =
      List.foldl(new_introspection_list, {%{}, %{}}, fn {interface, major, minor},
                                                        {introspection_map,
                                                         introspection_minor_map} ->
        introspection_map = Map.put(introspection_map, interface, major)
        introspection_minor_map = Map.put(introspection_minor_map, interface, minor)

        {introspection_map, introspection_minor_map}
      end)

    any_interface_id = SimpleTriggersProtobuf.Utils.any_interface_object_id()
    realm = new_state.realm

    %{device_triggers: device_triggers} =
      Core.Trigger.populate_triggers_for_object!(state, any_interface_id, :any_interface)

    device_id_string = Astarte.Core.Device.encode_device_id(new_state.device_id)

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
                  realm,
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
                  realm,
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

    # TODO this could be a bang!
    {:ok, old_minors} = Queries.fetch_device_introspection_minors(state.realm, state.device_id)

    readded_introspection = Enum.to_list(added_interfaces)

    old_introspection =
      Enum.reduce(removed_interfaces, %{}, fn {iface, _major}, acc ->
        prev_major = Map.fetch!(state.introspection, iface)
        prev_minor = Map.get(old_minors, iface, 0)
        Map.put(acc, {iface, prev_major}, prev_minor)
      end)

    :ok = Queries.add_old_interfaces(realm, new_state.device_id, old_introspection)
    :ok = Queries.remove_old_interfaces(realm, new_state.device_id, readded_introspection)

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
    new_state = Core.Interface.forget_interfaces(new_state, interfaces_to_drop_list)

    Queries.update_device_introspection!(
      realm,
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
        paths_cache: Cache.new(Config.paths_cache_size!()),
        total_received_msgs: new_state.total_received_msgs + 1,
        total_received_bytes: new_state.total_received_bytes + byte_size(payload)
    }
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

  @doc """
  Sets a device as disconnected, this does not foce device disconnection, but
  rather informs other astarte components that a device has been disconnected.
  """
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

  defp maybe_execute_device_disconnected_trigger(%State{connected: false}, _), do: :ok

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

  def prune_device_properties(state, decoded_payload, timestamp) do
    {:ok, paths_set} =
      PayloadsDecoder.parse_device_properties_payload(decoded_payload, state.introspection)

    Enum.each(state.introspection, fn {interface, _} ->
      # TODO: check result here
      Core.Interface.prune_interface(state, interface, paths_set, timestamp)
    end)

    :ok
  end

  def resend_all_properties(state) do
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
