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

defmodule Astarte.Events.Triggers.Cache do
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils
  alias Astarte.Events.Triggers.Core
  alias Astarte.Events.Triggers.Queries

  @event_targets :event_targets
  @trigger_lifetime_ttl :timer.minutes(1)

  @any_device_object_id Utils.any_device_object_id()
  @any_device_object_type Utils.object_type_to_int!(:any_device)
  @device_object_type Utils.object_type_to_int!(:device)
  @group_object_type Utils.object_type_to_int!(:group)

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
  def find_device_trigger_targets(realm_name, device_id, groups, event_key) do
    groups_caches = groups |> Enum.map(&group_cache(realm_name, event_key, &1))

    [
      any_device_cache(realm_name, event_key),
      device_cache(realm_name, event_key, device_id)
      | groups_caches
    ]
    |> Enum.concat()
  end

  defp any_device_cache(realm_name, event_key) do
    fetch_event(
      realm_name,
      event_key,
      :any_device,
      @any_device_object_id,
      @any_device_object_type
    )
  end

  defp device_cache(realm_name, event_key, device_id) do
    fetch_event(realm_name, event_key, {:device_id, device_id}, device_id, @device_object_type)
  end

  defp group_cache(realm_name, event_key, group_name) do
    group_id = Utils.get_group_object_id(group_name)
    fetch_event(realm_name, event_key, {:group, group_name}, group_id, @group_object_type)
  end

  defp fetch_event(realm_name, event_key, subject, object_id, object_type) do
    ConCache.get_or_store(@event_targets, {realm_name, subject}, fn ->
      fetch_triggers(realm_name, object_id, object_type)
    end)
    |> Map.get(event_key, [])
  end

  def fetch_triggers(realm_name, object_id, object_type) do
    simple_triggers =
      Queries.query_simple_triggers!(realm_name, object_id, object_type)
      |> Enum.map(&Core.deserialize_simple_trigger/1)

    # FIXME: this does not work for data triggers because they need the interfaces data
    {:ok, data} = Core.fetch_triggers(realm_name, simple_triggers)

    Map.merge(data.device_triggers, data.data_triggers)
    |> Map.new(fn {event_key, targets} ->
      targets_with_policies =
        for target <- targets do
          policy = Map.get(data.trigger_id_to_policy_name, target.parent_trigger_id)
          {target, policy}
        end

      {event_key, targets_with_policies}
    end)
  end

  def event_targets_cache_spec do
    {ConCache, con_cache_child_spec(@event_targets)}
  end

  @doc """
    Deletes all entries relative to a given realm from the cache. Its intended use is for tests.
  """
  def reset_realm_cache(realm_name) do
    ConCache.ets(@event_targets)
    |> :ets.select_delete([{{{realm_name, :'$1'}, :'$2'}, [], [true]}])
  end

  defp con_cache_child_spec(cache_id) do
    [
      name: cache_id,
      ttl_check_interval: :timer.seconds(1),
      global_ttl: @trigger_lifetime_ttl
    ]
  end
end
