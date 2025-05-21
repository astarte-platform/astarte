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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.Trigger do
  @moduledoc """
  Core part of the data_updater message processing.

  This module contains functions and utilities to process triggers.
  """
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.DataUpdaterPlant.TriggersHandler
  alias Astarte.DataUpdaterPlant.DataUpdater.EventTypeUtils
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf
  alias Astarte.Core.Triggers.DataTrigger
  alias Astarte.DataUpdaterPlant.TriggerPolicy.Queries, as: PolicyQueries
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger, as: ProtobufDeviceTrigger

  def populate_triggers_for_object!(state, object_id, object_type) do
    %{realm: realm} = state

    object_type_int = SimpleTriggersProtobuf.Utils.object_type_to_int!(object_type)

    simple_triggers = Queries.query_simple_triggers!(realm, object_id, object_type_int)

    new_state =
      Enum.reduce(simple_triggers, state, fn simple_trigger, state_acc ->
        trigger_data =
          SimpleTriggersProtobuf.Utils.deserialize_simple_trigger(simple_trigger.trigger_data)

        trigger_target =
          SimpleTriggersProtobuf.Utils.deserialize_trigger_target(simple_trigger.trigger_target)
          |> Map.put(:simple_trigger_id, simple_trigger.simple_trigger_id)
          |> Map.put(:parent_trigger_id, simple_trigger.parent_trigger_id)

        load_trigger(state_acc, trigger_data, trigger_target)
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

  def load_trigger(state, {:data_trigger, proto_buf_data_trigger}, trigger_target) do
    new_data_trigger =
      SimpleTriggersProtobuf.Utils.simple_trigger_to_data_trigger(proto_buf_data_trigger)

    data_triggers = state.data_triggers

    event_type = EventTypeUtils.pretty_data_trigger_type(proto_buf_data_trigger.data_trigger_type)
    data_trigger_key = Core.DataTrigger.data_trigger_to_key(state, new_data_trigger, event_type)
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
  def load_trigger(state, {:device_trigger, proto_buf_device_trigger}, trigger_target) do
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

  # TODO: consider what we should to with the cached policy if/when we allow updating a policy
  def maybe_cache_trigger_policy(state, %AMQPTriggerTarget{parent_trigger_id: parent_trigger_id}) do
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

  def populate_triggers_for_group_and_interface!(state, interface_id) do
    Enum.map(
      state.groups,
      &SimpleTriggersProtobuf.Utils.get_group_and_interface_object_id(&1, interface_id)
    )
    |> Enum.reduce(
      state,
      &populate_triggers_for_object!(&2, &1, :group_and_interface)
    )
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
    SimpleTriggersProtobuf.Utils.get_interface_id_or_any(interface_name, interface_major)
  end
end
