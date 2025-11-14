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
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.Triggers.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger, as: ProtobufDataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils, as: SimpleTriggersProtobufUtils
  alias Astarte.DataAccess.Realms.SimpleTrigger
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.EventTypeUtils
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.TriggersHandler
  alias Astarte.Events.Triggers

  def populate_triggers_for_object!(state, object_id, object_type) do
    %{realm: realm} = state

    object_type_int = SimpleTriggersProtobuf.Utils.object_type_to_int!(object_type)

    simple_triggers =
      Queries.query_simple_triggers!(realm, object_id, object_type_int)
      |> Enum.map(&Triggers.deserialize_simple_trigger/1)

    {:ok, new_data} =
      Triggers.fetch_triggers(realm, simple_triggers, Map.from_struct(state))

    new_state = Map.merge(state, new_data)
    object_key = {object_id, object_type_int}

    volatile_triggers =
      new_state.volatile_triggers
      |> Enum.filter(fn {trigger_key, _} -> trigger_key == object_key end)
      |> Enum.map(fn {_, simple_trigger} -> simple_trigger end)

    {:ok, new_data} =
      Triggers.fetch_triggers(realm, volatile_triggers, Map.from_struct(new_state))

    Map.merge(new_state, new_data)
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

  def execute_pre_change_triggers(context) do
    %{value: value, previous_value: previous_value} = context
    old_bson_value = Cyanide.encode!(%{v: previous_value})
    payload = Cyanide.encode!(%{v: value})

    if previous_value != value do
      TriggersHandler.value_change(
        context,
        old_bson_value,
        payload
      )
    end

    :ok
  end

  def execute_post_change_triggers(context) do
    %{value: value, previous_value: previous_value} = context
    old_bson_value = Cyanide.encode!(%{v: previous_value})
    payload = Cyanide.encode!(%{v: value})

    case {previous_value, value} do
      {value, value} ->
        :ok

      {nil, _value} ->
        TriggersHandler.path_created(context, payload)

      {_previous_value, nil} ->
        TriggersHandler.path_removed(context)

      {_previous_value, _value} ->
        TriggersHandler.value_change_applied(context, old_bson_value, payload)
    end
  end

  def execute_device_error_triggers(state, error_name, error_metadata \\ %{}, timestamp) do
    timestamp_ms = div(timestamp, 10_000)

    TriggersHandler.device_error(
      state.realm,
      state.device_id,
      state.groups,
      error_name,
      error_metadata,
      timestamp_ms
    )

    :ok
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
    trigger = %SimpleTrigger{
      trigger_data: simple_trigger,
      trigger_target: trigger_target,
      simple_trigger_id: trigger_id,
      parent_trigger_id: parent_id
    }

    deserialized_trigger = Triggers.deserialize_simple_trigger(trigger)
    {trigger_data, _trigger_target} = deserialized_trigger

    with {:ok, new_state} <- maybe_load_missing_interface(state, trigger_data),
         {:ok, new_data} <-
           Triggers.fetch_triggers(
             state.realm,
             [deserialized_trigger],
             Map.from_struct(new_state)
           ) do
      object_key = {object_id, object_type}
      new_volatile_trigger = {object_key, deserialized_trigger}

      new_state =
        Map.merge(new_state, new_data)
        |> Map.update!(:volatile_triggers, &[new_volatile_trigger | &1])

      Triggers.install_volatile_trigger(
        new_state.realm,
        deserialized_trigger,
        new_data
      )

      {:ok, new_state}
    else
      error ->
        # rollback
        {error, state}
    end
  end

  defp maybe_load_missing_interface(state, {:device_trigger, _}), do: {:ok, state}
  defp maybe_load_missing_interface(state, {_data, %{interface_name: "*"}}), do: {:ok, state}

  defp maybe_load_missing_interface(state, {_data, data_trigger}) do
    %ProtobufDataTrigger{
      interface_name: interface_name,
      interface_major: major,
      match_path: match_path
    } = data_trigger

    with {:ok, descriptor, new_state} <- handle_cache_miss(state, interface_name),
         :ok <- check_interface_major_version(descriptor, major),
         :ok <- check_trigger_path(match_path, descriptor.automaton) do
      {:ok, new_state}
    end
  end

  defp handle_cache_miss(state, interface_name) do
    maybe_descriptor = Map.get(state.interfaces, interface_name)

    case Core.Interface.maybe_handle_cache_miss(maybe_descriptor, interface_name, state) do
      {:ok, _interface_descriptor, _new_state} = ok -> ok
      {:error, :interface_loading_failed} -> {:error, :interface_not_found}
    end
  end

  defp check_trigger_path("/*", _automaton) do
    :ok
  end

  defp check_trigger_path(path, automaton) do
    case EndpointsAutomaton.resolve_path(path, automaton) do
      {:ok, _endpoint_id} -> :ok
      {:guessed, _} -> {:error, :invalid_match_path}
      {:error, :not_found} -> {:error, :invalid_match_path}
    end
  end

  defp check_interface_major_version(descriptor, major) do
    case descriptor.major_version do
      ^major -> :ok
      _ -> {:error, :interface_major_version_mismatch}
    end
  end

  def handle_delete_volatile_trigger(state, trigger_id) do
    Triggers.delete_volatile_trigger(state.realm, trigger_id)

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
end
