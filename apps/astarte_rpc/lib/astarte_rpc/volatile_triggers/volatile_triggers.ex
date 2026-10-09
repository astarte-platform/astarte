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

defmodule Astarte.RPC.VolatileTriggers do
  @moduledoc """
  Functions to operate on triggers
  """

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Events.Triggers.Core, as: EventsCore
  alias Astarte.RPC.Server
  alias Astarte.RPC.Triggers
  alias Astarte.RPC.Triggers.Core
  alias Astarte.RPC.VolatileTriggers.VolatileTriggerDeletion
  alias Astarte.RPC.VolatileTriggers.VolatileTriggerInstallation
  alias Phoenix.PubSub

  def subscribe_all, do: PubSub.subscribe(Server, "volatile-triggers:*")

  def subscribe_types(types) do
    Enum.each(types, fn type ->
      PubSub.subscribe(Server, trigger_by_type_key(type))
    end)
  end

  @spec install(
          String.t(),
          TaggedSimpleTrigger.t(),
          AMQPTriggerTarget.t(),
          EventsCore.fetch_triggers_data()
        ) :: :ok | {:error, term()}
  def install(realm_name, tagged_simple_trigger, target, data \\ %{}) do
    with {:ok, data} <- Core.find_trigger_data(realm_name, tagged_simple_trigger, data) do
      message =
        %VolatileTriggerInstallation{
          realm_name: realm_name,
          simple_trigger: tagged_simple_trigger,
          target: target,
          data: data
        }

      trigger_by_type_key = to_trigger_by_type_key(tagged_simple_trigger)
      broadcast(trigger_by_type_key, message)
    end
  end

  @doc """
  Deletes a volatile trigger. `event_type` is used to route the message to the interested
  subscribers, and can be either a trigger type (e.g. :DEVICE_CONNECTED) or a simple event
  type (e.g. :device_connected_event).
  """

  @spec delete(String.t(), Astarte.DataAccess.UUID.t(), TaggedSimpleTrigger.t()) ::
          :ok | {:error, term()}
  def delete(realm_name, trigger_id, %TaggedSimpleTrigger{} = tagged_simple_trigger) do
    message =
      %VolatileTriggerDeletion{
        realm_name: realm_name,
        trigger_id: trigger_id
      }

    broadcast(to_trigger_by_type_key(tagged_simple_trigger), message)
  end

  @spec delete(String.t(), Astarte.DataAccess.UUID.t(), atom()) :: :ok | {:error, term()}
  def delete(realm_name, trigger_id, event_type) do
    message =
      %VolatileTriggerDeletion{
        realm_name: realm_name,
        trigger_id: trigger_id
      }

    broadcast(trigger_by_type_key(EventsCore.pretty_trigger_type(event_type)), message)
  end

  defp broadcast(trigger_by_type_key, message) do
    PubSub.broadcast(Server, trigger_by_type_key, message)
    PubSub.broadcast(Server, "volatile-triggers:*", message)
  end

  defp to_trigger_by_type_key(tagged_simple_trigger) do
    trigger_type =
      Triggers.trigger_type(tagged_simple_trigger.simple_trigger_container.simple_trigger)

    trigger_type
    |> EventsCore.pretty_trigger_type()
    |> trigger_by_type_key()
  end

  defp trigger_by_type_key(trigger_type) do
    "volatile-triggers-by-type:" <> Atom.to_string(trigger_type)
  end
end
