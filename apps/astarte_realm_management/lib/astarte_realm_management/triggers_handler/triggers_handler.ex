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

defmodule Astarte.RealmManagement.TriggersHandler do
  alias Astarte.Core.Triggers.SimpleEvents.DeviceDeletionStartedEvent
  alias Astarte.Events.Triggers
  alias Astarte.Events.TriggersHandler
  alias Astarte.RealmManagement.Config

  @cache_id Config.trigger_cache!()

  defdelegate register_target(target, realm_name), to: TriggersHandler

  def device_deletion_started(realm_name, device_id) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    event_type = :on_device_deletion_started

    find_targets(realm_name, device_id, event_type)
    |> dispatch_all(realm_name, device_id, timestamp, event_type, %DeviceDeletionStartedEvent{})
  end

  defp dispatch_all(targets, realm_name, device_id, timestamp, event_type, event) do
    targets
    |> Enum.map(fn {target, policy} ->
      TriggersHandler.dispatch_event(
        event,
        event_type,
        target,
        realm_name,
        device_id,
        timestamp,
        policy
      )
    end)
    |> Enum.all?(&(&1 == :ok))
    |> case do
      true -> :ok
      false -> :error
    end
  end

  defp find_targets(realm_name, device_id, event_type) do
    load_triggers(realm_name)
    |> Triggers.find_trigger_targets_for_device(realm_name, device_id, event_type)
  end

  defp load_triggers(realm_name) do
    ConCache.get_or_store(@cache_id, realm_name, fn ->
      Triggers.fetch_realm_device_trigger(realm_name)
    end)
  end
end
