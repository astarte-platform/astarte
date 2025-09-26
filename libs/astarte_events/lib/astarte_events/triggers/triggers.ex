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
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils
  alias Astarte.DataAccess.Realms.SimpleTrigger
  alias Astarte.Events.Triggers.Core

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
