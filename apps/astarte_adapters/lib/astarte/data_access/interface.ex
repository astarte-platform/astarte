#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.DataAccess.Adapters.Interface do
  @moduledoc """
  Mapping to Astarte.DataAccess.Interface
  """
  use Astarte.Adapters

  import Astarte.Core.CQLUtils, only: [endpoint_id: 3]
  import Astarte.DataAccess.Realms.Interface, only: [storage: 1, storage_type: 1]

  alias Astarte.Core.Interface, as: InterfaceCore
  alias Astarte.Core.Mapping.EndpointsAutomaton

  transform from_core_interface_to_change do
    @source InterfaceCore.t()
    @returns %{interface: map(), endpoints: list(map())}

    field :interface, &interface_change/1
    field :endpoints <- :mappings, &mappings/2
  end

  transformp interface_change do
    pre_process &interface_change_pre_process/1

    keep :interface_id,
         :name,
         :major_version,
         :minor_version,
         :aggregation,
         :ownership,
         :type,
         :automaton_accepting_states,
         :automaton_transitions

    field :storage, &storage/1
    field :storage_type, &storage_type/1
    field :doc <- :doc, required: false
    field :description <- :description, required: false
  end

  transformp mapping do
    keep :interface_id,
         :endpoint,
         :value_type,
         :reliability,
         :retention,
         :expiry,
         :database_retention_policy,
         :allow_unset,
         :explicit_timestamp,
         :required,
         :endpoint_id,
         :interface_name,
         :interface_major_version,
         :interface_minor_version,
         :interface_type

    field :database_retention_ttl <- :database_retention_ttl, required: false
    field :doc <- :doc, required: false
    field :description <- :description, required: false
    field :encrypted <- :encrypted, required: false
  end

  defp interface_change_pre_process(
         %InterfaceCore{
           major_version: major_version,
           mappings: mappings,
           name: name
         } = interface
       ) do
    {:ok, {transitions, accepting_states}} = EndpointsAutomaton.build(mappings)
    accepting_states = accepting_states(Map.to_list(accepting_states), name, major_version, %{})

    interface
    |> Map.put(:automaton_accepting_states, :erlang.term_to_binary(accepting_states))
    |> Map.put(:automaton_transitions, :erlang.term_to_binary(transitions))
  end

  defp accepting_states([], _name, _major_version, acc), do: acc

  defp accepting_states([{state, endpoint} | accepting_states], name, major_version, acc),
    do:
      accepting_states(
        accepting_states,
        name,
        major_version,
        Map.put(acc, state, endpoint_id(name, major_version, endpoint))
      )

  defp mappings(
         mappings,
         %InterfaceCore{
           interface_id: interface_id,
           major_version: major_version,
           minor_version: minor_version,
           name: name,
           type: type
         }
       ) do
    interface = %{
      interface_id: interface_id,
      interface_major_version: major_version,
      interface_minor_version: minor_version,
      interface_name: name,
      interface_type: type
    }

    Enum.map(mappings, &mapping(Map.merge(&1, interface)))
  end
end
