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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.Interface do
  @moduledoc """
  Core part of the data_updater message processing.

  This module contains functions and utilities to process interfaces.
  """
  alias Astarte.Core.Mapping
  alias Astarte.Core.CQLUtils
  alias Astarte.DataUpdaterPlant.ValueMatchOperators
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.TriggersHandler
  alias Astarte.DataAccess.Mappings
  alias Astarte.DataAccess.Interface
  alias Astarte.DataAccess.Device

  require Logger

  @interface_lifespan_decimicroseconds 60 * 10 * 1000 * 10000

  def maybe_handle_cache_miss(nil, interface_name, state) do
    with {:ok, major_version} <-
           Device.interface_version(state.realm, state.device_id, interface_name),
         {:ok, interface_row} <-
           Interface.retrieve_interface_row(state.realm, interface_name, major_version),
         %InterfaceDescriptor{interface_id: interface_id} = interface_descriptor <-
           InterfaceDescriptor.from_db_result!(interface_row),
         {:ok, mappings} <-
           Mappings.fetch_interface_mappings_map(state.realm, interface_id),
         new_interfaces_by_expiry <-
           state.interfaces_by_expiry ++
             [{state.last_seen_message + @interface_lifespan_decimicroseconds, interface_name}],
         new_state <- %State{
           state
           | interfaces: Map.put(state.interfaces, interface_name, interface_descriptor),
             interface_ids_to_name:
               Map.put(
                 state.interface_ids_to_name,
                 interface_id,
                 interface_name
               ),
             interfaces_by_expiry: new_interfaces_by_expiry,
             mappings: Map.merge(state.mappings, mappings)
         },
         new_state <-
           Core.Trigger.populate_triggers_for_object!(
             new_state,
             interface_descriptor.interface_id,
             :interface
           ),
         device_and_interface_object_id =
           SimpleTriggersProtobuf.Utils.get_device_and_interface_object_id(
             state.device_id,
             interface_id
           ),
         new_state =
           Core.Trigger.populate_triggers_for_object!(
             new_state,
             device_and_interface_object_id,
             :device_and_interface
           ),
         new_state =
           Core.Trigger.populate_triggers_for_group_and_interface!(
             new_state,
             interface_id
           ) do
      # TODO: make everything with-friendly
      {:ok, interface_descriptor, new_state}
    else
      # Known errors. TODO: handle specific cases (e.g. ask for new introspection etc.)
      {:error, :interface_not_in_introspection} ->
        {:error, :interface_loading_failed}

      {:error, :device_not_found} ->
        {:error, :interface_loading_failed}

      {:error, :database_error} ->
        {:error, :interface_loading_failed}

      {:error, :interface_not_found} ->
        {:error, :interface_loading_failed}

      other ->
        Logger.warning("maybe_handle_cache_miss failed: #{inspect(other)}")
        {:error, :interface_loading_failed}
    end
  end

  def maybe_handle_cache_miss(interface_descriptor, _interface_name, state) do
    {:ok, interface_descriptor, state}
  end

  def prune_interface(state, interface, all_paths_set, timestamp) do
    with {:ok, interface_descriptor, new_state} <-
           maybe_handle_cache_miss(
             Map.get(state.interfaces, interface),
             interface,
             state
           ) do
      cond do
        interface_descriptor.type != :properties ->
          # TODO: nobody uses new_state
          {:ok, new_state}

        interface_descriptor.ownership != :device ->
          Logger.warning("Tried to prune server owned interface: #{interface}.")
          {:error, :maybe_outdated_introspection}

        true ->
          do_prune(new_state, interface_descriptor, all_paths_set, timestamp)
          # TODO: nobody uses new_state
          {:ok, new_state}
      end
    end
  end

  defp do_prune(state, interface_descriptor, all_paths_set, timestamp) do
    each_interface_mapping(state.mappings, interface_descriptor, fn mapping ->
      endpoint_id = mapping.endpoint_id

      Queries.all_device_owned_property_endpoint_paths!(
        state.realm,
        state.device_id,
        interface_descriptor,
        endpoint_id
      )
      |> Enum.each(fn path ->
        if not MapSet.member?(all_paths_set, {interface_descriptor.name, path}) do
          device_id_string = Astarte.Core.Device.encode_device_id(state.device_id)

          {:ok, endpoint_id} =
            EndpointsAutomaton.resolve_path(path, interface_descriptor.automaton)

          Queries.delete_property_from_db(
            state.realm,
            state.device_id,
            interface_descriptor,
            endpoint_id,
            path
          )

          interface_id = interface_descriptor.interface_id

          path_removed_triggers =
            get_on_data_triggers(state, :on_path_removed, interface_id, endpoint_id, path)

          i_name = interface_descriptor.name

          Enum.each(path_removed_triggers, fn trigger ->
            target_with_policy_list =
              trigger.trigger_targets
              |> Enum.map(fn target ->
                {target, Map.get(state.trigger_id_to_policy_name, target.parent_trigger_id)}
              end)

            TriggersHandler.path_removed(
              target_with_policy_list,
              state.realm,
              device_id_string,
              i_name,
              path,
              timestamp
            )
          end)
        end
      end)
    end)
  end

  def get_on_data_triggers(state, event, interface_id, endpoint_id) do
    key = {event, interface_id, endpoint_id}

    Map.get(state.data_triggers, key, [])
  end

  def get_on_data_triggers(state, event, interface_id, endpoint_id, path, value \\ nil) do
    key = {event, interface_id, endpoint_id}

    candidate_triggers = Map.get(state.data_triggers, key, nil)

    if candidate_triggers do
      ["" | path_tokens] = String.split(path, "/")

      for trigger <- candidate_triggers,
          path_matches?(path_tokens, trigger.path_match_tokens) and
            ValueMatchOperators.value_matches?(
              value,
              trigger.value_match_operator,
              trigger.known_value
            ) do
        trigger
      end
    else
      []
    end
  end

  defp path_matches?([], []) do
    true
  end

  defp path_matches?([path_token | path_tokens], [path_match_token | path_match_tokens]) do
    if path_token == path_match_token or path_match_token == "" do
      path_matches?(path_tokens, path_match_tokens)
    else
      false
    end
  end

  def each_interface_mapping(mappings, interface_descriptor, fun) do
    Enum.each(mappings, fn {_endpoint_id, mapping} ->
      if mapping.interface_id == interface_descriptor.interface_id do
        fun.(mapping)
      end
    end)
  end

  def resolve_path(path, interface_descriptor, mappings) do
    case interface_descriptor.aggregation do
      :individual ->
        with {:ok, endpoint_id} <-
               EndpointsAutomaton.resolve_path(path, interface_descriptor.automaton),
             {:ok, endpoint} <- Map.fetch(mappings, endpoint_id) do
          {:ok, endpoint}
        else
          :error ->
            # Map.fetch failed
            Logger.warning(
              "endpoint_id for path #{inspect(path)} not found in mappings #{inspect(mappings)}."
            )

            {:error, :mapping_not_found}

          {:error, reason} ->
            Logger.warning(
              "EndpointsAutomaton.resolve_path failed with reason #{inspect(reason)}."
            )

            {:error, :mapping_not_found}

          {:guessed, guessed_endpoints} ->
            {:guessed, guessed_endpoints}
        end

      :object ->
        with {:guessed, [first_endpoint_id | _tail] = guessed_endpoints} <-
               EndpointsAutomaton.resolve_path(path, interface_descriptor.automaton),
             :ok <- check_object_aggregation_prefix(path, guessed_endpoints, mappings),
             {:ok, first_mapping} <- Map.fetch(mappings, first_endpoint_id) do
          # We return the first guessed mapping changing just its endpoint id, using the canonical
          # endpoint id used in object aggregated interfaces. This way all mapping properties
          # (database_retention_ttl, reliability etc) are correctly set since they're the same in
          # all mappings (this is enforced by Realm Management when the interface is installed)

          endpoint_id =
            CQLUtils.endpoint_id(
              interface_descriptor.name,
              interface_descriptor.major_version,
              ""
            )

          {:ok, %{first_mapping | endpoint_id: endpoint_id}}
        else
          {:ok, _endpoint_id} ->
            # This is invalid here, publish doesn't happen on endpoints in object aggregated interfaces
            Logger.warning(
              "Tried to publish on endpoint #{inspect(path)} for object aggregated " <>
                "interface #{inspect(interface_descriptor.name)}. You should publish on " <>
                "the common prefix",
              tag: "invalid_path"
            )

            {:error, :mapping_not_found}

          {:error, :not_found} ->
            Logger.warning(
              "Tried to publish on invalid path #{inspect(path)} for object aggregated " <>
                "interface #{inspect(interface_descriptor.name)}",
              tag: "invalid_path"
            )

            {:error, :mapping_not_found}

          {:error, :invalid_object_aggregation_path} ->
            Logger.warning(
              "Tried to publish on invalid path #{inspect(path)} for object aggregated " <>
                "interface #{inspect(interface_descriptor.name)}",
              tag: "invalid_path"
            )

            {:error, :mapping_not_found}
        end
    end
  end

  defp check_object_aggregation_prefix(path, guessed_endpoints, mappings) do
    received_path_depth = path_or_endpoint_depth(path)

    Enum.reduce_while(guessed_endpoints, :ok, fn
      endpoint_id, _acc ->
        with {:ok, %Mapping{endpoint: endpoint}} <- Map.fetch(mappings, endpoint_id),
             endpoint_depth when received_path_depth == endpoint_depth - 1 <-
               path_or_endpoint_depth(endpoint) do
          {:cont, :ok}
        else
          _ ->
            {:halt, {:error, :invalid_object_aggregation_path}}
        end
    end)
  end

  defp path_or_endpoint_depth(path) when is_binary(path) do
    String.split(path, "/", trim: true)
    |> length()
  end

  def extract_expected_types(_path, interface_descriptor, endpoint, mappings) do
    case interface_descriptor.aggregation do
      :individual ->
        endpoint.value_type

      :object ->
        # TODO: we should probably cache this
        Enum.flat_map(mappings, fn {_id, mapping} ->
          if mapping.interface_id == interface_descriptor.interface_id do
            expected_key =
              mapping.endpoint
              |> String.split("/")
              |> List.last()

            [{expected_key, mapping.value_type}]
          else
            []
          end
        end)
        |> Enum.into(%{})
    end
  end

  def forget_interfaces(state, []) do
    state
  end

  def forget_interfaces(state, interfaces_to_drop) do
    iface_ids_to_drop =
      Enum.filter(interfaces_to_drop, &Map.has_key?(state.interfaces, &1))
      |> Enum.map(fn iface ->
        Map.fetch!(state.interfaces, iface).interface_id
      end)

    updated_triggers =
      Enum.reduce(iface_ids_to_drop, state.data_triggers, fn interface_id, data_triggers ->
        Enum.reject(data_triggers, fn {{_event_type, iface_id, _endpoint}, _val} ->
          iface_id == interface_id
        end)
        |> Enum.into(%{})
      end)

    updated_mappings =
      Enum.reduce(iface_ids_to_drop, state.mappings, fn interface_id, mappings ->
        Enum.reject(mappings, fn {_endpoint_id, mapping} ->
          mapping.interface_id == interface_id
        end)
        |> Enum.into(%{})
      end)

    updated_ids =
      Enum.reduce(iface_ids_to_drop, state.interface_ids_to_name, fn interface_id, ids ->
        Map.delete(ids, interface_id)
      end)

    updated_interfaces =
      Enum.reduce(interfaces_to_drop, state.interfaces, fn iface, ifaces ->
        Map.delete(ifaces, iface)
      end)

    %{
      state
      | interfaces: updated_interfaces,
        interface_ids_to_name: updated_ids,
        mappings: updated_mappings,
        data_triggers: updated_triggers
    }
  end
end
