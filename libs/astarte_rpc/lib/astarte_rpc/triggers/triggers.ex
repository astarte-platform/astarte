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

defmodule Astarte.RPC.Triggers do
  @moduledoc """
  Functions to operate on triggers
  """

  alias Astarte.RPC.Server
  alias Astarte.RPC.Triggers.Core
  alias Astarte.RPC.Triggers.TriggerDeletion
  alias Astarte.RPC.Triggers.TriggerInstallation
  alias Phoenix.PubSub

  def subscribe_all, do: PubSub.subscribe(Server, "triggers:*")

  def notify_installation(realm_name, tagged_simple_trigger, target, policy, data \\ %{}) do
    with {:ok, data} <- Core.find_trigger_data(realm_name, tagged_simple_trigger, data) do
      message =
        %TriggerInstallation{
          realm_name: realm_name,
          simple_trigger: tagged_simple_trigger,
          target: target,
          policy: policy,
          data: data
        }

      PubSub.broadcast(Server, "triggers:*", message)
    end
  end

  def notify_deletion(realm_name, trigger_id, tagged_simple_trigger, data \\ %{}) do
    with {:ok, data} <- Core.find_trigger_data(realm_name, tagged_simple_trigger, data) do
      message =
        %TriggerDeletion{
          realm_name: realm_name,
          trigger_id: trigger_id,
          simple_trigger: tagged_simple_trigger,
          data: data
        }

      PubSub.broadcast(Server, "triggers:*", message)
    end
  end
end
