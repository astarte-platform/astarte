#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.Core.Mapping.EndpointsAutomaton do
  @moduledoc """
  Provides automaton-based endpoint matching for Astarte mappings.
  """

  alias Astarte.Core.Mapping

  @doc """
  returns `:ok` and an endpoint for a given `path` using a previously built automata (`{transitions, accepting_states}`).
  if path is not complete one or more endpoints will be guessed and `:guessed` followed by a list of endpoints is returned.
  """
  def resolve_path(path, {transitions, accepting_states}) do
    path_tokens = String.split(path, "/", trim: true)

    states = do_transitions(path_tokens, [0], transitions)

    cond do
      states == [] ->
        {:error, :not_found}

      length(states) == 1 and accepting_states[hd(states)] != nil ->
        {:ok, accepting_states[hd(states)]}

      true ->
        states = force_transitions(states, transitions, accepting_states)

        guessed_endpoints =
          for state <- states do
            accepting_states[state]
          end

        {:guessed, guessed_endpoints}
    end
  end

  @doc """
  builds the automaton for given `mappings`, returns `:ok` followed by the automaton tuple if build succeeded, otherwise `:error` and the reason.
  """
  def build(mappings) do
    nfa = do_build(mappings)

    if valid?(nfa, mappings) do
      {:ok, nfa}
    else
      {:error, :overlapping_mappings}
    end
  end

  @doc """
  returns true if `nfa` is valid for given `mappings`
  """
  def valid?(nfa, mappings) do
    Enum.all?(mappings, fn mapping ->
      resolve_path(mapping.endpoint, nfa) == {:ok, mapping.endpoint}
    end)
  end

  @doc """
  returns a list of likely invalid endpoints for a certain list of `mappings`.
  """
  def lint(mappings) do
    nfa = do_build(mappings)

    mappings
    |> Enum.filter(fn mapping ->
      resolve_path(mapping.endpoint, nfa) != {:ok, mapping.endpoint}
    end)
    |> Enum.map(fn mapping -> mapping.endpoint end)
  end

  defp do_transitions([], current_states, _transitions) do
    current_states
  end

  defp do_transitions(_tokens, [], _transitions) do
    []
  end

  defp do_transitions([token | tail_tokens], current_states, transitions) do
    next_states =
      List.foldl(current_states, [], fn state, acc ->
        if Mapping.is_placeholder?(token) do
          all_state_transitions = state_transitions(transitions, state)

          all_state_transitions ++ acc
        else
          transition_list = Map.get(transitions, {state, token}) |> List.wrap()
          epsi_transition_list = Map.get(transitions, {state, ""}) |> List.wrap()

          transition_list ++ epsi_transition_list ++ acc
        end
      end)

    do_transitions(tail_tokens, next_states, transitions)
  end

  defp force_transitions(current_states, transitions, accepting_states) do
    next_states =
      List.foldl(current_states, [], fn state, acc ->
        good_state =
          if accepting_states[state] == nil do
            state_transitions(transitions, state)
          else
            [state]
          end

        good_state ++ acc
      end)

    finished =
      Enum.all?(next_states, fn state ->
        accepting_states[state]
      end)

    if finished do
      next_states
    else
      force_transitions(next_states, transitions, accepting_states)
    end
  end

  defp state_transitions(transitions, state) do
    Enum.reduce(transitions, [], fn
      {{^state, _}, next_state}, acc ->
        [next_state | acc]

      _transition, acc ->
        acc
    end)
  end

  defp do_build(mappings) do
    {transitions, _, accepting_states} = List.foldl(mappings, {%{}, [], %{}}, &parse_endpoint/2)

    {transitions, accepting_states}
  end

  def parse_endpoint(mapping, {transitions, states, accepting_states}) do
    ["" | path_tokens] =
      mapping.endpoint
      |> Mapping.normalize_endpoint()
      |> String.split("/")

    {states, _, _, transitions} =
      List.foldl(path_tokens, {states, 0, "", transitions}, fn token,
                                                               {states, previous_state,
                                                                partial_endpoint, transitions} ->
        new_partial_endpoint = "#{partial_endpoint}/#{token}"

        candidate_previous =
          Enum.find_index(states, fn state -> state == new_partial_endpoint end)

        if candidate_previous != nil do
          {states, candidate_previous, new_partial_endpoint, transitions}
        else
          states = states ++ [partial_endpoint]
          new_state = length(states)

          {states, new_state, new_partial_endpoint,
           Map.put(transitions, {previous_state, token}, new_state)}
        end
      end)

    accepting_states = Map.put(accepting_states, length(states), mapping.endpoint)

    {transitions, states, accepting_states}
  end
end
