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

defmodule Astarte.Events.Triggers do
  alias Astarte.Core.Device
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils
  alias Astarte.DataAccess.Realms.SimpleTrigger
  alias Astarte.Events.Triggers.Core
  alias Astarte.Events.Triggers.Queries

  @type trigger_key() :: atom() | {atom(), Astarte.DataAccess.UUID.t() | :any_interface}
  @type deserialized_simple_trigger() :: {term(), term()}

  @type fetch_triggers_data() ::
          %{
            optional(term()) => term(),
            data_triggers: %{trigger_key() => [AMQPTriggerTarget.t()]},
            device_triggers: %{trigger_key() => [AMQPTriggerTarget.t()]},
            trigger_id_to_policy_name: %{Astarte.DataAccess.UUID.t() => String.t()},
            interfaces: %{String.t() => InterfaceDescriptor.t()},
            interface_ids_to_name: %{Astarte.DataAccess.UUID.t() => String.t()}
          }

  @type event_type() :: atom()
  @type event_condition() :: :any_device | {:device_id, binary()} | {:group_name, String.t()}
  @type realm_device_trigger_key() :: {event_type(), event_condition()}
  @type policy_name() :: String.t() | nil
  @type target_and_policy() :: {AMQPTriggerTarget.t(), policy_name()}
  @type realm_device_trigger_map() :: %{realm_device_trigger_key() => [target_and_policy()]}

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

    deserialized_simple_triggers
    |> Enum.reduce_while({:ok, initial_result}, fn {trigger_data, trigger_target},
                                                   {:ok, result} ->
      case Core.load_trigger(realm_name, trigger_data, trigger_target, result) do
        {:ok, _} = new_result -> {:cont, new_result}
        error -> {:halt, error}
      end
    end)
  end

  @doc """
    Fetches all device triggers for a realm.
    The returned value can be used by `find_trigger_targets_for_device/5` to selectively find all the targets for a given event.
  """
  @spec fetch_realm_device_trigger(String.t()) :: realm_device_trigger_map()
  def fetch_realm_device_trigger(realm_name) do
    device_simple_triggers =
      Queries.get_realm_simple_triggers(realm_name)
      |> Enum.map(&deserialize_simple_trigger/1)
      |> Enum.filter(fn {{type, _trigger}, _target} -> type == :device_trigger end)

    Core.register_targets(realm_name, device_simple_triggers)

    trigger_id_to_policy_name =
      Core.build_trigger_id_to_policy_name_map(realm_name, device_simple_triggers)

    device_simple_triggers
    |> Enum.map(fn {{:device_trigger, trigger}, target} ->
      condition =
        case {trigger.device_id, trigger.group_name} do
          {nil, nil} ->
            :any_device

          {nil, group} ->
            {:group, group}

          {device_id, _group} ->
            {:ok, device_id} = Device.decode_device_id(device_id)
            {:device_id, device_id}
        end

      event = Core.pretty_device_event_type(trigger.device_event_type)
      policy = Map.get(trigger_id_to_policy_name, target.parent_trigger_id)

      {event, condition, {target, policy}}
    end)
    |> Enum.group_by(
      fn {event, condition, _target_and_policy} -> {event, condition} end,
      fn {_event, _condition, target_and_policy} -> target_and_policy end
    )
  end

  @doc """
    Returns the list of targets for a given device and event.
    The device trigger map can be built using `fetch_realm_device_trigger/1`
  """
  @spec find_trigger_targets_for_device(
          realm_device_trigger_map(),
          String.t(),
          Astarte.DataAccess.UUID.t(),
          event_type(),
          [String.t()] | nil
        ) :: [target_and_policy()]
  def find_trigger_targets_for_device(
        realm_device_triggers,
        realm_name,
        device_id,
        event_type,
        groups \\ nil
      ) do
    device_groups = groups || Queries.get_device_groups(realm_name, device_id)

    realm_device_triggers
    |> Enum.flat_map(fn
      {{^event_type, :any_device}, value} ->
        value

      {{^event_type, {:device_id, ^device_id}}, value} ->
        value

      {{^event_type, {:group, group_name}}, value} ->
        case group_name in device_groups do
          true -> value
          false -> []
        end

      _ ->
        []
    end)
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
end
