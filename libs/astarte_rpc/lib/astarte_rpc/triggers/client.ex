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

defmodule Astarte.RPC.Triggers.Client do
  use GenServer

  alias Astarte.RPC.Triggers
  alias Astarte.RPC.Triggers.Client
  alias Astarte.RPC.Triggers.TriggerDeletion
  alias Astarte.RPC.Triggers.TriggerInstallation
  alias Astarte.Events.Triggers, as: EventsTriggers

  def start_link(init_arg), do: GenServer.start_link(Client, init_arg, name: Client)

  @impl GenServer
  def init(opts) do
    case Keyword.fetch(opts, :types) do
      {:ok, trigger_types} -> Triggers.subscribe_types(trigger_types)
      :error -> Triggers.subscribe_all()
    end

    {:ok, nil}
  end

  @impl GenServer
  def handle_info(%TriggerInstallation{} = message, state) do
    %TriggerInstallation{
      realm_name: realm_name,
      simple_trigger: simple_trigger,
      target: target,
      policy: policy,
      data: data
    } = message

    EventsTriggers.install_trigger(realm_name, simple_trigger, target, policy, data)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%TriggerDeletion{} = message, state) do
    %TriggerDeletion{
      realm_name: realm_name,
      trigger_id: trigger_id,
      simple_trigger: simple_trigger,
      data: data
    } = message

    EventsTriggers.delete_trigger(realm_name, trigger_id, simple_trigger, data)

    {:noreply, state}
  end
end
