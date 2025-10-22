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

defmodule Astarte.Events.Triggers.Core do
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.Triggers.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger, as: ProtobufDataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger, as: ProtobufDeviceTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils
  alias Astarte.Events.TriggersHandler.Core
  alias Astarte.Events.Triggers.Queries

  @type trigger_data ::
          {:data_trigger, ProtobufDataTrigger.t()} | {:device_trigger, ProtobufDeviceTrigger.t()}
  @type device_event_key ::
          :on_device_connection
          | :on_device_disconnection
          | :on_empty_cache_received
          | :on_device_error
          | :on_incoming_introspection
          | {:on_interface_added, String.t()}
          | {:on_interface_removed, String.t()}
          | {:on_interface_minor_updated, String.t()}
          | :on_device_registered
          | :on_device_deletion_started
          | :on_device_deletion_finished

  @type data_trigger_event ::
          :on_incoming_data
          | :on_value_change
          | :on_value_change_applied
          | :on_path_created
          | :on_path_removed
          | :on_value_stored

  @type endpoint :: Astarte.DataAccess.UUID.t() | :any_endpoint
  @type interface :: Astarte.DataAccess.UUID.t() | :any_interface
  @type data_event_key :: {data_trigger_event(), interface(), endpoint()}
  @type event_key :: device_event_key() | data_event_key()

  @type deserialized_simple_trigger() :: {trigger_data(), AMQPTriggerTarget.t()}

  @type fetch_triggers_data() ::
          %{
            optional(term()) => term(),
            data_triggers: %{data_event_key() => [AMQPTriggerTarget.t()]},
            device_triggers: %{device_event_key() => [AMQPTriggerTarget.t()]},
            trigger_id_to_policy_name: %{Astarte.DataAccess.UUID.t() => String.t()},
            interfaces: %{String.t() => InterfaceDescriptor.t()},
            interface_ids_to_name: %{Astarte.DataAccess.UUID.t() => String.t()}
          }

  def register_targets(realm_name, simple_trigger_list) do
    for {_trigger_key, target} <- simple_trigger_list do
      Core.register_target(realm_name, target)
    end
  end

  def load_trigger(realm_name, {:data_trigger, proto_buf_data_trigger}, trigger_target, state) do
    new_data_trigger = Utils.simple_trigger_to_data_trigger(proto_buf_data_trigger)

    data_triggers = state.data_triggers

    event_type = pretty_data_trigger_type(proto_buf_data_trigger.data_trigger_type)

    with {:ok, data_trigger_key} <- data_trigger_to_key(state, new_data_trigger, event_type) do
      existing_triggers_for_key = Map.get(data_triggers, data_trigger_key, [])

      # Extract all the targets belonging to the (eventual) existing congruent trigger
      congruent_targets =
        existing_triggers_for_key
        |> Enum.filter(&DataTrigger.are_congruent?(&1, new_data_trigger))
        |> Enum.flat_map(fn congruent_trigger -> congruent_trigger.trigger_targets end)

      new_targets = [trigger_target | congruent_targets]
      new_data_trigger_with_targets = %{new_data_trigger | trigger_targets: new_targets}

      # Register the new target
      :ok = Core.register_target(realm_name, trigger_target)

      # Replace the (eventual) congruent existing trigger with the new one
      new_data_triggers_for_key = [
        new_data_trigger_with_targets
        | Enum.reject(
            existing_triggers_for_key,
            &DataTrigger.are_congruent?(&1, new_data_trigger_with_targets)
          )
      ]

      next_data_triggers = Map.put(data_triggers, data_trigger_key, new_data_triggers_for_key)

      new_state = Map.put(state, :data_triggers, next_data_triggers)

      {:ok, new_state}
    end
  end

  # TODO: implement on_empty_cache_received
  def load_trigger(realm_name, {:device_trigger, proto_buf_device_trigger}, trigger_target, state) do
    device_triggers = state.device_triggers
    # device event type is one of
    # :on_device_connected, :on_device_disconnected, :on_device_empty_cache_received, :on_device_error,
    # :on_incoming_introspection, :on_interface_added, :on_interface_removed, :on_interface_minor_updated
    event_type = pretty_device_event_type(proto_buf_device_trigger.device_event_type)

    # introspection triggers have a pair as key, standard device ones do not
    trigger_key = device_trigger_to_key(event_type, proto_buf_device_trigger)

    existing_trigger_targets = Map.get(device_triggers, trigger_key, [])

    new_targets = [trigger_target | existing_trigger_targets]

    # Register the new target
    :ok = Core.register_target(realm_name, trigger_target)

    next_device_triggers = Map.put(device_triggers, trigger_key, new_targets)
    # Map.put(state, :introspection_triggers, next_introspection_triggers)
    new_state = Map.put(state, :device_triggers, next_device_triggers)

    {:ok, new_state}
  end

  @spec fetch_endpoint(map(), DataTrigger.path_match_tokens(), DataTrigger.interface_id()) ::
          {:ok, Astarte.DataAccess.UUID.t() | :any_endpoint}
          | {:error, :interface_not_found | :invalid_match_path}
  defp fetch_endpoint(state, path_match_tokens, interface_id) do
    if path_match_tokens == :any_endpoint or interface_id == :any_interface do
      {:ok, :any_endpoint}
    else
      interface_name = Map.get(state.interface_ids_to_name, interface_id)

      case Map.fetch(state.interfaces, interface_name) do
        :error ->
          {:error, :interface_not_found}

        {:ok, interface_descriptor} ->
          path_no_root =
            path_match_tokens
            |> Enum.map(&replace_empty_token/1)
            |> Enum.join("/")

          case EndpointsAutomaton.resolve_path("/#{path_no_root}", interface_descriptor.automaton) do
            {:ok, endpoint_id} -> {:ok, endpoint_id}
            _ -> {:error, :invalid_match_path}
          end
      end
    end
  end

  defp replace_empty_token(""), do: "%{}"
  defp replace_empty_token(non_empty), do: non_empty

  def data_trigger_to_key(state, data_trigger, event_type) do
    %DataTrigger{
      path_match_tokens: path_match_tokens,
      interface_id: interface_id
    } = data_trigger

    with {:ok, endpoint} <- fetch_endpoint(state, path_match_tokens, interface_id) do
      {:ok, {event_type, interface_id, endpoint}}
    end
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
    Utils.get_interface_id_or_any(interface_name, interface_major)
  end

  defp pretty_data_trigger_type(data_trigger_type) do
    case data_trigger_type do
      :INCOMING_DATA ->
        :on_incoming_data

      :VALUE_CHANGE ->
        :on_value_change

      :VALUE_CHANGE_APPLIED ->
        :on_value_change_applied

      :PATH_CREATED ->
        :on_path_created

      :PATH_REMOVED ->
        :on_path_removed

      :VALUE_STORED ->
        :on_value_stored
    end
  end

  def pretty_device_event_type(device_event_type) do
    case device_event_type do
      :DEVICE_CONNECTED ->
        :on_device_connection

      :DEVICE_DISCONNECTED ->
        :on_device_disconnection

      :DEVICE_EMPTY_CACHE_RECEIVED ->
        :on_empty_cache_received

      :DEVICE_ERROR ->
        :on_device_error

      :INCOMING_INTROSPECTION ->
        :on_incoming_introspection

      :INTERFACE_ADDED ->
        :on_interface_added

      :INTERFACE_REMOVED ->
        :on_interface_removed

      :INTERFACE_MINOR_UPDATED ->
        :on_interface_minor_updated

      :DEVICE_REGISTERED ->
        :on_device_registered

      :DEVICE_DELETION_STARTED ->
        :on_device_deletion_started

      :DEVICE_DELETION_FINISHED ->
        :on_device_deletion_finished
    end
  end

  def build_trigger_id_to_policy_name_map(realm_name, simple_triggers) do
    trigger_ids =
      simple_triggers
      |> Enum.map(fn {_trigger, target} -> target.parent_trigger_id end)
      |> Enum.uniq()

    Queries.get_policy_name_map(realm_name, trigger_ids)
  end

  @spec cache_trigger_id_to_policy_names(fetch_triggers_data(), String.t(), [
          deserialized_simple_trigger()
        ]) :: fetch_triggers_data()
  def cache_trigger_id_to_policy_names(state, realm_name, deserialized_simple_triggers) do
    existing_trigger_id_to_policy_names =
      state.trigger_id_to_policy_name |> Map.keys() |> MapSet.new()

    simple_trigger_parent_trigger_ids =
      deserialized_simple_triggers
      |> Enum.map(fn {_trigger, target} -> target.parent_trigger_id end)
      |> MapSet.new()

    potentially_missing_trigger_ids =
      MapSet.difference(simple_trigger_parent_trigger_ids, existing_trigger_id_to_policy_names)
      |> MapSet.to_list()

    new_trigger_id_to_policy_name_cache =
      Queries.get_policy_name_map(realm_name, potentially_missing_trigger_ids)

    Map.update!(
      state,
      :trigger_id_to_policy_name,
      &Map.merge(&1, new_trigger_id_to_policy_name_cache)
    )
  end
end
