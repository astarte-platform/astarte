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
  alias Astarte.Core.Device
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils
  alias Astarte.Events.Triggers.Core
  alias Astarte.Events.Triggers.DataTrigger
  alias Astarte.Events.Triggers.Queries

  @event_targets :event_targets
  @event_volatile_targets :event_volatile_targets
  @trigger_id :trigger_id

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
    subject = :any_device

    fetch_cache(realm_name, event_key, subject, @any_device_object_id, @any_device_object_type)
  end

  defp device_cache(realm_name, event_key, device_id) do
    subject = {:device_id, device_id}

    fetch_cache(realm_name, event_key, subject, device_id, @device_object_type)
  end

  defp group_cache(realm_name, event_key, group_name) do
    group_id = Utils.get_group_object_id(group_name)
    subject = {:group, group_name}

    fetch_cache(realm_name, event_key, subject, group_id, @group_object_type)
  end

  defp fetch_cache(realm_name, event_key, subject, object_id, object_type) do
    triggers = fetch_event(realm_name, event_key, subject, object_id, object_type)
    volatile_triggers = fetch_volatile_event(realm_name, event_key, subject)

    Enum.concat(triggers, volatile_triggers)
  end

  defp fetch_event(realm_name, event_key, subject, object_id, object_type) do
    ConCache.get_or_store(@event_targets, {realm_name, subject}, fn ->
      fetch_triggers(realm_name, object_id, object_type)
    end)
    |> Map.get(event_key, [])
  end

  defp fetch_volatile_event(realm_name, event_key, subject) do
    key = volatile_events_id(realm_name, subject, event_key)
    ConCache.get(@event_volatile_targets, key) || []
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

  def install_volatile_trigger(
        realm_name,
        event_key,
        subject,
        trigger_type,
        trigger,
        target,
        policy
      ) do
    trigger_cache_key = trigger_cache_id(realm_name, target.simple_trigger_id)
    volatile_trigger_key = volatile_events_id(realm_name, subject, event_key)

    ConCache.isolated(@trigger_id, trigger_cache_key, fn ->
      ConCache.update(
        @event_volatile_targets,
        volatile_trigger_key,
        &do_install_volatile_trigger(realm_name, trigger_type, target, policy, trigger, &1)
      )

      trigger_cache = {trigger_type, realm_name, subject, event_key, trigger}

      ConCache.dirty_put(
        @trigger_id,
        trigger_cache_key,
        trigger_cache
      )
    end)

    :ok
  end

  defp do_install_volatile_trigger(realm_name, trigger_type, target, policy, trigger, events) do
    events =
      case events do
        nil -> []
        events -> events
      end

    new_events =
      case trigger_type do
        :device_trigger ->
          Core.load_device_trigger_targets_with_policy(realm_name, events, target, policy)

        :data_trigger ->
          Core.load_data_trigger_targets_with_policy(
            realm_name,
            events,
            target,
            policy,
            trigger
          )
      end

    {:ok, new_events}
  end

  def delete_volatile_trigger(realm_name, trigger_id) do
    cache_key = trigger_cache_id(realm_name, trigger_id)

    ConCache.isolated(@trigger_id, cache_key, fn ->
      case ConCache.get(@trigger_id, cache_key) do
        nil ->
          :ok

        {:device_trigger, realm_name, subject, event_key, _trigger} ->
          delete_device_trigger(realm_name, trigger_id, subject, event_key)

        {:data_trigger, realm_name, subject, event_key, data_trigger} ->
          delete_data_trigger(realm_name, trigger_id, subject, event_key, data_trigger)
      end
    end)
  end

  defp delete_device_trigger(realm_name, trigger_id, subject, event_key) do
    update_function = fn trigger_list -> do_delete_device_trigger(trigger_id, trigger_list) end
    do_delete_trigger(realm_name, trigger_id, subject, event_key, update_function)
  end

  defp delete_data_trigger(realm_name, trigger_id, subject, event_key, data_trigger) do
    update_function = fn trigger_list ->
      do_delete_data_trigger(trigger_id, data_trigger, trigger_list)
    end

    do_delete_trigger(realm_name, trigger_id, subject, event_key, update_function)
  end

  defp do_delete_trigger(realm_name, trigger_id, subject, event_key, update_function) do
    cache_key = volatile_events_id(realm_name, subject, event_key)

    ConCache.isolated(@event_volatile_targets, cache_key, fn ->
      case ConCache.dirty_update_existing(@event_volatile_targets, cache_key, update_function) do
        :ok -> :ok
        {:error, :not_existing} -> :ok
        {:error, :empty} -> ConCache.dirty_delete(@event_volatile_targets, cache_key)
      end
    end)

    cache_key = trigger_cache_id(realm_name, trigger_id)
    ConCache.dirty_delete(@trigger_id, cache_key)
  end

  defp do_delete_device_trigger(trigger_id, triggers) do
    triggers
    |> Enum.reject(fn {target, _policy} -> target.simple_trigger_id == trigger_id end)
    |> case do
      [] -> {:error, :empty}
      trigger_list -> {:ok, trigger_list}
    end
  end

  defp do_delete_data_trigger(trigger_id, orig_data_trigger, data_trigger_list) do
    data_trigger_list
    |> Enum.map(fn data_trigger ->
      case DataTrigger.are_congruent?(data_trigger, orig_data_trigger) do
        true -> remove_trigger_from_data_trigger(data_trigger, trigger_id)
        false -> data_trigger
      end
    end)
    |> Enum.reject(&(&1.trigger_targets == []))
    |> case do
      [] -> {:error, :empty}
      data_trigger_list -> {:ok, data_trigger_list}
    end
  end

  defp remove_trigger_from_data_trigger(data_trigger, trigger_id) do
    update_in(
      data_trigger.trigger_targets,
      &Enum.reject(&1, fn {target, _policy} -> target.simple_trigger_id == trigger_id end)
    )
  end

  defp volatile_events_id(realm_name, subject, event_key), do: {realm_name, subject, event_key}
  defp trigger_cache_id(realm_name, trigger_id), do: {realm_name, trigger_id}

  def trigger_subject(hw_id, group_name) do
    case {hw_id, group_name} do
      {nil, nil} ->
        {:ok, :any_device}

      {"*", nil} ->
        {:ok, :any_device}

      {hw_id, nil} ->
        with {:ok, device_id} <- Device.decode_device_id(hw_id, allow_extended_id: true) do
          {:ok, {:device_id, device_id}}
        end

      {_, group_name} ->
        {:ok, {:group, group_name}}
    end
  end

  def event_targets_cache_spec do
    con_cache_child_spec(@event_targets)
  end

  def event_volatile_targets_cache_spec do
    con_cache_no_expiry_child_spec(@event_volatile_targets)
  end

  def trigger_id_cache_spec do
    con_cache_no_expiry_child_spec(@trigger_id)
  end

  @doc """
    Deletes all entries relative to a given realm from the cache. Its intended use is for tests.
  """
  def reset_realm_cache(realm_name) do
    ConCache.ets(@event_targets)
    |> :ets.select_delete([{{{realm_name, :"$1"}, :"$2"}, [], [true]}])

    ConCache.ets(@event_volatile_targets)
    |> :ets.select_delete([{{{realm_name, :"$1", :"$2"}, :"$3"}, [], [true]}])

    ConCache.ets(@trigger_id)
    |> :ets.select_delete([{{{realm_name, :"$1"}, :"$2"}, [], [true]}])
  end

  defp con_cache_child_spec(cache_id) do
    params = [
      name: cache_id,
      ttl_check_interval: :timer.seconds(1),
      global_ttl: @trigger_lifetime_ttl
    ]

    Supervisor.child_spec({ConCache, params}, id: {ConCache, cache_id})
  end

  defp con_cache_no_expiry_child_spec(cache_id) do
    params = [
      name: cache_id,
      ttl_check_interval: false
    ]

    Supervisor.child_spec({ConCache, params}, id: {ConCache, cache_id})
  end
end
