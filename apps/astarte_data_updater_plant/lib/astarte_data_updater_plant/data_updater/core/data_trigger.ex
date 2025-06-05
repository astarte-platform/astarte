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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.DataTrigger do
  @moduledoc """

  """
  alias Astarte.DataUpdaterPlant.TriggersHandler
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Triggers.DataTrigger
  alias Astarte.DataUpdaterPlant.DataUpdater.Core

  def data_trigger_to_key(state, data_trigger, event_type) do
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

  def execute_incoming_data_triggers(
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

  defp replace_empty_token(""), do: "%{}"
  defp replace_empty_token(non_empty), do: non_empty

  defp get_target_with_policy_list(state, trigger) do
    trigger.trigger_targets
    |> Enum.map(fn target ->
      parent_target_id = Map.get(state.trigger_id_to_policy_name, target.parent_trigger_id)

      {target, parent_target_id}
    end)
  end
end
