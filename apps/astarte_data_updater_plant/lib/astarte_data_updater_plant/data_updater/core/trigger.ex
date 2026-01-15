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
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger, as: ProtobufDataTrigger
  alias Astarte.DataAccess.Realms.SimpleTrigger
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.TriggersHandler
  alias Astarte.Events.Triggers

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

    with {:ok, new_state} <- maybe_load_missing_interface(state, trigger_data) do
      result =
        Triggers.install_volatile_trigger(
          state.realm,
          deserialized_trigger,
          Map.from_struct(new_state)
        )

      {result, new_state}
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
    :ok
  end
end
