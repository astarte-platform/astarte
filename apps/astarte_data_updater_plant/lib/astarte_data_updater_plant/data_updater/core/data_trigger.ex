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
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Triggers.DataTrigger

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

  defp replace_empty_token(token) do
    case token do
      "" ->
        "%{}"

      not_empty ->
        not_empty
    end
  end
end
