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
  alias Astarte.Events.Triggers.Core
  alias Astarte.Events.Triggers.DataTrigger
  alias Astarte.Events.Triggers.Queries

  @event_targets :event_targets
  @event_volatile_targets :event_volatile_targets
  @trigger_id :trigger_id

  @trigger_lifetime_ttl :timer.minutes(1)

  @doc """
    Returns the list of targets for a device event.
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

  @doc """
    Returns the list of targets for a data event.
  """
  @spec find_data_trigger_targets(
          String.t(),
          Astarte.DataAccess.UUID.t(),
          [String.t()],
          Core.event_key(),
          Core.fetch_triggers_data()
        ) :: [Core.target_and_policy()]
  def find_data_trigger_targets(realm_name, device_id, groups, event_key, data) do
    find_data_triggers(realm_name, device_id, groups, event_key, data)
    |> Enum.flat_map(& &1.trigger_targets)
  end

  @doc """
    Returns the list of targets for a data event with a path and value.
  """
  @spec find_data_trigger_targets(
          String.t(),
          Astarte.DataAccess.UUID.t(),
          [String.t()],
          Core.data_event_key(),
          [String.t()],
          term(),
          Core.fetch_triggers_data()
        ) :: [Core.target_and_policy()]
  def find_data_trigger_targets(
        realm_name,
        device_id,
        groups,
        event_key,
        path_tokens,
        value,
        data
      ) do
    find_data_triggers(realm_name, device_id, groups, event_key, data)
    |> Enum.filter(&Core.valid_trigger_for_value?(&1, path_tokens, value))
    |> Enum.flat_map(& &1.trigger_targets)
  end

  @doc """
    Returns data triggers for a data event.
    Use `find_data_trigger_targets/5` instead to retrieve trigger targets.
  """
  @spec find_data_triggers(
          String.t(),
          Astarte.DataAccess.UUID.t(),
          [String.t()],
          Core.data_event_key(),
          Core.fetch_triggers_data()
        ) :: [DataTrigger.t()]
  def find_data_triggers(realm_name, device_id, groups, event_key, data) do
    interface_ids =
      case Map.fetch(data, :interface_ids_to_name) do
        :error -> []
        {:ok, interface_id_to_name} -> Map.keys(interface_id_to_name)
      end

    interface = Enum.map(interface_ids, &interface_cache(realm_name, event_key, &1, data))

    device_and_interface =
      Enum.map(
        interface_ids,
        &device_and_interface_cache(realm_name, event_key, device_id, &1, data)
      )

    group_and_any_interface =
      Enum.map(groups, &group_and_any_interface_cache(realm_name, event_key, &1, data))

    groups_and_interfaces =
      for interface_id <- interface_ids,
          group <- groups do
        group_and_interface_cache(realm_name, event_key, group, interface_id, data)
      end

    [
      any_interface_cache(realm_name, event_key, data),
      device_and_any_interface_cache(realm_name, event_key, device_id, data),
      device_and_interface,
      interface,
      group_and_any_interface,
      groups_and_interfaces
    ]
    |> List.flatten()
  end

  defp any_device_cache(realm_name, event_key) do
    subject = :any_device

    device_trigger_cache(realm_name, event_key, subject)
  end

  defp device_cache(realm_name, event_key, device_id) do
    subject = {:device_id, device_id}

    device_trigger_cache(realm_name, event_key, subject)
  end

  defp group_cache(realm_name, event_key, group_name) do
    subject = {:group, group_name}

    device_trigger_cache(realm_name, event_key, subject)
  end

  defp device_and_any_interface_cache(realm_name, event_key, device_id, data) do
    subject = {:device_and_any_interface, device_id}

    data_trigger_cache(
      realm_name,
      event_key,
      subject,
      data
    )
  end

  defp device_and_interface_cache(realm_name, event_key, device_id, interface_id, data) do
    subject = {:device_and_interface, device_id, interface_id}

    data_trigger_cache(
      realm_name,
      event_key,
      subject,
      data
    )
  end

  defp any_interface_cache(realm_name, event_key, data) do
    subject = :any_interface

    data_trigger_cache(
      realm_name,
      event_key,
      subject,
      data
    )
  end

  defp interface_cache(realm_name, event_key, interface_id, data) do
    subject = {:interface, interface_id}

    data_trigger_cache(realm_name, event_key, subject, data)
  end

  defp group_and_any_interface_cache(realm_name, event_key, group_name, data) do
    subject = {:group_and_any_interface, group_name}

    data_trigger_cache(
      realm_name,
      event_key,
      subject,
      data
    )
  end

  defp group_and_interface_cache(realm_name, event_key, group, interface_id, data) do
    subject = {:group_and_interface, group, interface_id}

    data_trigger_cache(
      realm_name,
      event_key,
      subject,
      data
    )
  end

  defp device_trigger_cache(realm_name, event_key, subject) do
    {object_type, object_id} = Core.object_from_subject(subject)
    triggers = fetch_device_event(realm_name, event_key, object_id, object_type)
    volatile_triggers = fetch_volatile_event(realm_name, event_key, subject)

    Enum.concat(triggers, volatile_triggers)
  end

  defp data_trigger_cache(realm_name, event_key, subject, data) do
    {object_type, object_id} = Core.object_from_subject(subject)
    triggers = fetch_data_event(realm_name, event_key, object_id, object_type, data)
    volatile_triggers = fetch_volatile_event(realm_name, event_key, subject)

    Enum.concat(triggers, volatile_triggers)
  end

  defp fetch_device_event(realm_name, event_key, object_id, object_type) do
    store_function = fn -> fetch_device_triggers(realm_name, object_id, object_type) end
    fetch_event(realm_name, event_key, object_id, object_type, store_function)
  end

  defp fetch_data_event(realm_name, event_key, object_id, object_type, data) do
    store_function = fn -> fetch_data_triggers(realm_name, object_id, object_type, data) end
    fetch_event(realm_name, event_key, object_id, object_type, store_function)
  end

  defp fetch_event(realm_name, event_key, object_id, object_type, store_function) do
    target_id = event_target_id(realm_name, object_id, object_type)

    ConCache.get_or_store(@event_targets, target_id, store_function)
    |> Map.get(event_key, [])
  end

  defp fetch_volatile_event(realm_name, event_key, subject) do
    key = volatile_events_id(realm_name, subject, event_key)
    ConCache.get(@event_volatile_targets, key) || []
  end

  def fetch_device_triggers(realm_name, object_id, object_type) do
    simple_triggers =
      Queries.query_simple_triggers!(realm_name, object_id, object_type)
      |> Enum.map(&Core.deserialize_simple_trigger/1)

    {:ok, data} = Core.fetch_triggers(realm_name, simple_triggers)

    data.device_triggers
    |> Map.new(fn {event_key, targets} ->
      targets_with_policies =
        for target <- targets do
          policy = Map.get(data.trigger_id_to_policy_name, target.parent_trigger_id)
          {target, policy}
        end

      {event_key, targets_with_policies}
    end)
  end

  def fetch_data_triggers(realm_name, object_id, object_type, data) do
    simple_triggers =
      Queries.query_simple_triggers!(realm_name, object_id, object_type)
      |> Enum.map(&Core.deserialize_simple_trigger/1)

    data = Map.put(data, :data_triggers, %{})

    # SAFETY: triggers are fetched based on the interfaces inside data, so we
    #   are sure this always returns `{:ok, data}`
    {:ok, data} = Core.fetch_triggers(realm_name, simple_triggers, data)

    data.data_triggers
    |> Map.new(fn {event_key, data_triggers} ->
      data_triggers_with_policy =
        for data_trigger <- data_triggers do
          DataTrigger.from_core(data_trigger, data.trigger_id_to_policy_name)
        end

      {event_key, data_triggers_with_policy}
    end)
  end

  def install_trigger(realm_name, event_key, object, trigger_type, trigger, target, policy, data) do
    {object_type, object_id} = object
    event_target_id = event_target_id(realm_name, object_id, object_type)

    update_function =
      &load_event_trigger(
        realm_name,
        object,
        event_key,
        trigger_type,
        target,
        policy,
        trigger,
        &1,
        data
      )

    ConCache.update(
      @event_targets,
      event_target_id,
      update_function
    )
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
        &load_trigger(realm_name, trigger_type, target, policy, trigger, &1)
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

  defp load_event_trigger(
         realm_name,
         object,
         _event_key,
         trigger_type,
         _target,
         _policy,
         _trigger,
         nil = _event_map,
         data
       ) do
    {object_type, object_id} = object
    # If we do not have a current trigger state, we have to read from the database anyway to avoid
    # dirty states.
    # The new trigger is stored on the database before the notification is sent, so we don't need
    # to do anything else
    result =
      case trigger_type do
        :device_trigger -> fetch_device_triggers(realm_name, object_id, object_type)
        :data_trigger -> fetch_data_triggers(realm_name, object_id, object_type, data)
      end

    {:ok, result}
  end

  defp load_event_trigger(
         realm_name,
         _object,
         event_key,
         trigger_type,
         target,
         policy,
         trigger,
         event_map,
         _data
       ) do
    events = Map.get(event_map, event_key, [])

    new_events =
      Core.load_trigger_with_policy(realm_name, trigger_type, target, policy, trigger, events)

    result = Map.put(event_map, event_key, new_events)
    {:ok, result}
  end

  defp load_trigger(realm_name, trigger_type, target, policy, trigger, events) do
    events =
      case events do
        nil -> []
        events -> events
      end

    new_events =
      Core.load_trigger_with_policy(realm_name, trigger_type, target, policy, trigger, events)

    {:ok, new_events}
  end

  @spec delete_volatile_trigger(String.t(), Astarte.DataAccess.UUID.t()) :: :ok
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

  defp event_target_id(realm_name, object_id, object_type),
    do: {realm_name, object_id, object_type}

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
    |> :ets.select_delete([{{{realm_name, :"$1", :"$2"}, :"$3"}, [], [true]}])

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
