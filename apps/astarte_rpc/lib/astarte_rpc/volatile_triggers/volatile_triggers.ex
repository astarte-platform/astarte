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
  alias Astarte.RPC.Triggers.Core
  alias Astarte.RPC.VolatileTriggers.VolatileTriggerDeletion
  alias Astarte.RPC.VolatileTriggers.VolatileTriggerInstallation
  alias Phoenix.PubSub

  def subscribe_all, do: PubSub.subscribe(Server, "volatile-triggers:*")

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

      broadcast(message)
    end
  end

  @spec delete(String.t(), Astarte.DataAccess.UUID.t()) :: :ok | {:error, term()}
  def delete(realm_name, trigger_id) do
    message =
      %VolatileTriggerDeletion{
        realm_name: realm_name,
        trigger_id: trigger_id
      }

    broadcast(message)
  end

  defp broadcast(message) do
    PubSub.broadcast(Server, "volatile-triggers:*", message)
  end
end
