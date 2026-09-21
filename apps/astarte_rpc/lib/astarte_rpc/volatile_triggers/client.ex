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

defmodule Astarte.RPC.VolatileTriggers.Client do
  @moduledoc """
  This module defines the GenServer responsible for handling trigger installation and deletion messages in the Astarte RPC system.
  """
  use GenServer

  alias Astarte.Events.Triggers, as: EventsTriggers
  alias Astarte.RPC.VolatileTriggers
  alias Astarte.RPC.VolatileTriggers.Client
  alias Astarte.RPC.VolatileTriggers.VolatileTriggerDeletion
  alias Astarte.RPC.VolatileTriggers.VolatileTriggerInstallation

  def start_link(init_arg), do: GenServer.start_link(Client, init_arg, name: Client)

  @impl GenServer
  def init(_opts) do
    VolatileTriggers.subscribe_all()

    {:ok, nil}
  end

  @impl GenServer
  def handle_info(%VolatileTriggerInstallation{} = message, state) do
    %VolatileTriggerInstallation{
      realm_name: realm_name,
      simple_trigger: simple_trigger,
      target: target,
      data: data
    } = message

    EventsTriggers.install_volatile_trigger(realm_name, simple_trigger, target, data)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(%VolatileTriggerDeletion{} = message, state) do
    %VolatileTriggerDeletion{
      realm_name: realm_name,
      trigger_id: trigger_id
    } = message

    EventsTriggers.delete_volatile_trigger(realm_name, trigger_id)

    {:noreply, state}
  end
end
