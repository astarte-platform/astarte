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
  alias Astarte.Events.Triggers.Cache
  alias Astarte.Events.Triggers.Core
  alias Astarte.Events.Triggers.Queries

  defdelegate fetch_triggers(realm_name, deserialized_simple_triggers), to: Core
  defdelegate fetch_triggers(realm_name, deserialized_simple_triggers, data), to: Core

  @spec install_volatile_trigger(
          String.t(),
          Core.deserialized_simple_trigger(),
          Core.fetch_triggers_data()
        ) :: :ok
  def install_volatile_trigger(realm_name, deserialized_volatile_trigger, data \\ %{}) do
    {{trigger_type, trigger}, target} = deserialized_volatile_trigger

    with {:ok, event_key, new_trigger} <-
           Core.get_trigger_with_event_key(data, trigger_type, trigger),
         {:ok, subject} <- Cache.trigger_subject(trigger.device_id, trigger.group_name) do
      policy = Core.get_trigger_policy(realm_name, target)

      Cache.install_volatile_trigger(
        realm_name,
        event_key,
        subject,
        trigger_type,
        new_trigger,
        target,
        policy
      )
    end
  end

  defdelegate delete_volatile_trigger(realm_name, trigger_id), to: Cache

  @doc """
    Returns the list of targets for an event.
    This operation is an optimization and should only be used for device events.
  """
  @spec find_device_trigger_targets(
          String.t(),
          Astarte.DataAccess.UUID.t(),
          [String.t()] | nil,
          Core.event_key()
        ) :: [Core.target_and_policy()]
  def find_device_trigger_targets(
        realm_name,
        device_id,
        groups \\ nil,
        event_key
      ) do
    device_groups = groups || Queries.get_device_groups(realm_name, device_id)
    Cache.find_device_trigger_targets(realm_name, device_id, device_groups, event_key)
  end

  defdelegate deserialize_simple_trigger(trigger), to: Core
end
