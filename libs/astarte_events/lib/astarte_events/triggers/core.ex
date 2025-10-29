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
  alias Astarte.DataAccess.Realms.SimpleTrigger
  alias Astarte.Events.Triggers.DataTrigger, as: DataTriggerWithTargets
  alias Astarte.Events.TriggersHandler.Core
  alias Astarte.Events.Triggers.ValueMatchOperators
  alias Astarte.Events.Triggers.Queries

  @type data_trigger :: %ProtobufDataTrigger{}
  @type device_trigger :: %ProtobufDeviceTrigger{}
  @type trigger_data :: {:data_trigger, data_trigger()} | {:device_trigger, device_trigger()}

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
  @type deserialized_device_trigger() :: {ProtobufDeviceTrigger.t(), AMQPTriggerTarget.t()}

  @type policy_name() :: String.t() | nil
  @type target_and_policy() :: {AMQPTriggerTarget.t(), policy_name()}

  @type fetch_triggers_data() ::
          %{
            optional(term()) => term(),
            data_triggers: %{data_event_key() => [AMQPTriggerTarget.t()]},
            device_triggers: %{device_event_key() => [AMQPTriggerTarget.t()]},
            trigger_id_to_policy_name: DataTriggerWithTargets.trigger_id_to_policy_name(),
            interfaces: %{String.t() => InterfaceDescriptor.t()},
            interface_ids_to_name: %{Astarte.DataAccess.UUID.t() => String.t()}
          }

  def register_targets(realm_name, simple_trigger_list) do
    for {_trigger_key, target} <- simple_trigger_list do
      Core.register_target(realm_name, target)
    end
  end

  @doc """
    Fetches triggers associated with the given deserialized simple trigger list.
    The return value is a map with `:data_triggers`, `:device_triggers`, and additional values loaded from the database.
    Additional parameters are accepted, which can be used to initialize the return value for the cached item. In case of pre-existing 
    In case of the possibility of interface-driven data triggers, `:interfaces` and `:interface_ids_to_name` must be set to appropriate values.
  """
  @spec fetch_triggers(String.t(), [deserialized_simple_trigger()], fetch_triggers_data()) ::
          {:ok, fetch_triggers_data()} | {:error, term()}
  def fetch_triggers(realm_name, deserialized_simple_triggers, data \\ %{}) do
    initial_result =
      %{
        data_triggers: %{},
        device_triggers: %{},
        trigger_id_to_policy_name: %{},
        interfaces: %{},
        interface_ids_to_name: %{}
      }
      |> Map.merge(data)
      |> cache_trigger_id_to_policy_names(realm_name, deserialized_simple_triggers)

    deserialized_simple_triggers
    |> Enum.reduce_while({:ok, initial_result}, fn {trigger_data, trigger_target},
                                                   {:ok, result} ->
      case load_trigger(realm_name, trigger_data, trigger_target, result) do
        {:ok, _} = new_result -> {:cont, new_result}
        error -> {:halt, error}
      end
    end)
  end

  def load_trigger(realm_name, {:data_trigger, proto_buf_data_trigger}, trigger_target, state) do
    data_triggers = state.data_triggers

    with {:ok, data_trigger_key, new_data_trigger} <-
           get_trigger_with_event_key(state, :data_trigger, proto_buf_data_trigger) do
      existing_triggers_for_key = Map.get(data_triggers, data_trigger_key, [])

      new_data_triggers_for_key =
        load_data_trigger_targets(
          realm_name,
          existing_triggers_for_key,
          trigger_target,
          new_data_trigger
        )

      next_data_triggers = Map.put(data_triggers, data_trigger_key, new_data_triggers_for_key)

      new_state = Map.put(state, :data_triggers, next_data_triggers)

      {:ok, new_state}
    end
  end

  # TODO: implement on_empty_cache_received
  def load_trigger(realm_name, {:device_trigger, proto_buf_device_trigger}, trigger_target, state) do
    device_triggers = state.device_triggers

    trigger_key = device_trigger_to_key(proto_buf_device_trigger)

    existing_trigger_targets = Map.get(device_triggers, trigger_key, [])

    new_targets =
      load_device_trigger_targets(realm_name, existing_trigger_targets, trigger_target)

    next_device_triggers = Map.put(device_triggers, trigger_key, new_targets)
    # Map.put(state, :introspection_triggers, next_introspection_triggers)
    new_state = Map.put(state, :device_triggers, next_device_triggers)

    {:ok, new_state}
  end

  @spec load_data_trigger_targets(
          String.t(),
          [DataTrigger.t()],
          AMQPTriggerTarget.t(),
          DataTrigger.t()
        ) :: [DataTrigger.t()]
  def load_data_trigger_targets(
        realm_name,
        existing_triggers_for_key,
        trigger_target,
        new_data_trigger
      ) do
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
    [
      new_data_trigger_with_targets
      | Enum.reject(
          existing_triggers_for_key,
          &DataTrigger.are_congruent?(&1, new_data_trigger_with_targets)
        )
    ]
  end

  @spec load_device_trigger_targets(String.t(), [AMQPTriggerTarget.t()], AMQPTriggerTarget.t()) ::
          [AMQPTriggerTarget.t()]
  def load_device_trigger_targets(realm_name, existing_trigger_targets, trigger_target) do
    # Register the new target
    :ok = Core.register_target(realm_name, trigger_target)
    [trigger_target | existing_trigger_targets]
  end

  @spec load_data_trigger_targets_with_policy(
          String.t(),
          [DataTriggerWithTargets.t()],
          AMQPTriggerTarget.t(),
          policy_name(),
          DataTrigger.t()
        ) :: [DataTriggerWithTargets.t()]
  def load_data_trigger_targets_with_policy(
        realm_name,
        existing_triggers_for_key,
        trigger_target,
        policy,
        new_data_trigger
      ) do
    # Extract all the targets belonging to the (eventual) existing congruent trigger
    congruent_targets =
      existing_triggers_for_key
      |> Enum.filter(&DataTrigger.are_congruent?(&1, new_data_trigger))
      |> Enum.flat_map(fn congruent_trigger -> congruent_trigger.trigger_targets end)

    new_targets = [{trigger_target, policy} | congruent_targets]
    new_data_trigger_with_targets = %{new_data_trigger | trigger_targets: new_targets}

    # Register the new target
    :ok = Core.register_target(realm_name, trigger_target)

    # Replace the (eventual) congruent existing trigger with the new one
    [
      new_data_trigger_with_targets
      | Enum.reject(
          existing_triggers_for_key,
          &DataTrigger.are_congruent?(&1, new_data_trigger_with_targets)
        )
    ]
  end

  @spec load_device_trigger_targets_with_policy(
          String.t(),
          [target_and_policy()],
          AMQPTriggerTarget.t(),
          policy_name()
        ) :: [target_and_policy()]
  def load_device_trigger_targets_with_policy(
        realm_name,
        existing_trigger_targets,
        trigger_target,
        policy
      ) do
    # Register the new target
    :ok = Core.register_target(realm_name, trigger_target)
    [{trigger_target, policy} | existing_trigger_targets]
  end

  def get_trigger_with_event_key(_data, :device_trigger, trigger) do
    trigger_key = device_trigger_to_key(trigger)
    {:ok, trigger_key, trigger}
  end

  def get_trigger_with_event_key(data, :data_trigger, trigger) do
    new_data_trigger = Utils.simple_trigger_to_data_trigger(trigger)
    event_type = pretty_data_trigger_type(trigger.data_trigger_type)

    with {:ok, key} <- data_trigger_to_key(data, new_data_trigger, event_type) do
      {:ok, key, new_data_trigger}
    end
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

  defp device_trigger_to_key(proto_buf_device_trigger) do
    event_type = pretty_device_event_type(proto_buf_device_trigger.device_event_type)

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

  def get_trigger_policy(realm_name, trigger_target) do
    Queries.get_policy_name(realm_name, trigger_target.parent_trigger_id)
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

  @spec deserialize_simple_trigger(SimpleTrigger.t()) :: deserialized_simple_trigger()
  def deserialize_simple_trigger(simple_trigger) do
    trigger_data =
      Utils.deserialize_simple_trigger(simple_trigger.trigger_data)

    trigger_target =
      Utils.deserialize_trigger_target(simple_trigger.trigger_target)
      |> Map.put(:simple_trigger_id, simple_trigger.simple_trigger_id)
      |> Map.put(:parent_trigger_id, simple_trigger.parent_trigger_id)

    {trigger_data, trigger_target}
  end

  @spec path_matches?([String.t()], DataTriggerWithTargets.path_match_tokens()) :: boolean()
  defp path_matches?(_path_tokens, :any_endpoint), do: true

  defp path_matches?(path_tokens, path_match_tokens) do
    # SAFETY: Any endpoint configuration must not generate paths that are prefix of other paths

    Enum.zip(path_tokens, path_match_tokens)
    |> Enum.all?(fn {path_token, path_match_token} ->
      path_token == path_match_token or path_match_token == ""
    end)
  end

  @spec valid_trigger_for_value?(DataTriggerWithTargets.t(), [String.t()], term()) :: boolean()
  def valid_trigger_for_value?(trigger, path_tokens, value) do
    path_matches?(path_tokens, trigger.path_match_tokens) and
      ValueMatchOperators.value_matches?(value, trigger.value_match_operator, trigger.known_value)
  end
end
