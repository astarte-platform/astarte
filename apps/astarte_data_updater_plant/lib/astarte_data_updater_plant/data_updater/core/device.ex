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
  alias Astarte.DataUpdaterPlant.Config
  alias Astarte.DataUpdaterPlant.MessageTracker
  alias Astarte.DataUpdaterPlant.DataUpdater.Cache
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.Core.CQLUtils
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.TriggersHandler
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl

  require Logger

  def process_introspection(state, new_introspection_list, payload, message_id, timestamp) do
    new_state = Impl.execute_time_based_actions(state, timestamp)

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
end
