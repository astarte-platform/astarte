#
# This file is part of Astarte.
#
# Copyright 2022 - 2025 SECO Mind Srl
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

defmodule Astarte.TriggerEngine.Policy do
  use GenServer
  require Logger

  alias Astarte.TriggerEngine.Policy.Impl
  alias Astarte.TriggerEngine.Policy.State

  # API
  def start_link(args \\ []) do
    realm_name = Keyword.fetch!(args, :realm_name)
    policy = Keyword.fetch!(args, :policy)

    GenServer.start_link(__MODULE__, args, name: via_tuple(realm_name, policy.name))
  end

  def handle_event(pid, channel, payload, meta) do
    _ =
      Logger.debug(
        "policy process #{inspect(pid)} got event, payload: #{inspect(payload)},  meta: #{inspect(meta)}",
        tag: "policy_handle_event"
      )

    GenServer.cast(pid, {:handle_event, channel, payload, meta})
  end

  # Server callbacks

  def init(args) do
    policy = Keyword.get(args, :policy)
    state = %State{policy: policy, retry_map: %{}}
    {:ok, state}
  end

  def handle_cast(
        {:handle_event, chan, payload, meta},
        %State{policy: policy, retry_map: retry_map} = _state
      ) do
    new_state = Impl.handle_event(policy, retry_map, chan, payload, meta)
    {:noreply, new_state}
  end

  defp via_tuple(realm_name, policy_name) do
    {:via, Registry, {Registry.PolicyRegistry, {realm_name, policy_name}}}
  end
end
