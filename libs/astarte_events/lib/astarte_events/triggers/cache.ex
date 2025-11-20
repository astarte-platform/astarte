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
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger, as: ProtobufDeviceTrigger
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
  @any_interface_object_id Utils.any_interface_object_id()
  @any_interface_object_type Utils.object_type_to_int!(:any_interface)
  @interface_object_type Utils.object_type_to_int!(:interface)
  @device_and_any_interface_object_type Utils.object_type_to_int!(:device_and_any_interface)
  @device_and_interface_object_type Utils.object_type_to_int!(:device_and_interface)
  @group_and_any_interface_object_type Utils.object_type_to_int!(:group_and_any_interface)
  @group_and_interface_object_type Utils.object_type_to_int!(:group_and_interface)

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
          String.t(),
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

    device_cache(realm_name, event_key, subject, @any_device_object_id, @any_device_object_type)
  end

  defp device_cache(realm_name, event_key, device_id) do
    subject = {:device_id, device_id}

    device_cache(realm_name, event_key, subject, device_id, @device_object_type)
  end

  defp group_cache(realm_name, event_key, group_name) do
    group_id = Utils.get_group_object_id(group_name)
    subject = {:group, group_name}

    device_cache(realm_name, event_key, subject, group_id, @group_object_type)
  end

  defp device_and_any_interface_cache(realm_name, event_key, device_id, data) do
    object_id = Utils.get_device_and_any_interface_object_id(device_id)
    subject = {:device_and_any_interface, device_id}

    data_cache(
      realm_name,
      event_key,
      subject,
      object_id,
      @device_and_any_interface_object_type,
      data
    )
  end

  defp device_and_interface_cache(realm_name, event_key, device_id, interface_id, data) do
    object_id = Utils.get_device_and_interface_object_id(device_id, interface_id)
    subject = {:device_and_interface, device_id, interface_id}

    data_cache(
      realm_name,
      event_key,
      subject,
      object_id,
      @device_and_interface_object_type,
      data
    )
  end

  defp any_interface_cache(realm_name, event_key, data) do
    subject = :any_interface

    data_cache(
      realm_name,
      event_key,
      subject,
      @any_interface_object_id,
      @any_interface_object_type,
      data
    )
  end

  defp interface_cache(realm_name, event_key, interface_id, data) do
    subject = {:interface, interface_id}

    data_cache(realm_name, event_key, subject, interface_id, @interface_object_type, data)
  end

  defp group_and_any_interface_cache(realm_name, event_key, group_name, data) do
    object_id = Utils.get_group_and_any_interface_object_id(group_name)
    subject = {:group_and_any_interface, group_name}

    data_cache(
      realm_name,
      event_key,
      subject,
      object_id,
      @group_and_any_interface_object_type,
      data
    )
  end

  defp group_and_interface_cache(realm_name, event_key, group, interface_id, data) do
    object_id = Utils.get_group_and_interface_object_id(group, interface_id)
    subject = {:group_and_interface, group, interface_id}

    data_cache(
      realm_name,
      event_key,
      subject,
      object_id,
      @group_and_interface_object_type,
      data
    )
  end

  defp device_cache(realm_name, event_key, subject, object_id, object_type) do
    triggers = fetch_device_event(realm_name, event_key, object_id, object_type)
    volatile_triggers = fetch_volatile_event(realm_name, event_key, subject)

    Enum.concat(triggers, volatile_triggers)
  end

  defp data_cache(realm_name, event_key, subject, object_id, object_type, data) do
    triggers = fetch_data_event(realm_name, event_key, object_id, object_type, data)
    volatile_triggers = fetch_volatile_event(realm_name, event_key, subject)

    Enum.concat(triggers, volatile_triggers)
  end

  defp fetch_device_event(realm_name, event_key, object_id, object_type) do
    ConCache.get_or_store(@event_targets, {realm_name, object_id, object_type}, fn ->
      fetch_device_triggers(realm_name, object_id, object_type)
    end)
    |> Map.get(event_key, [])
  end

  defp fetch_data_event(realm_name, event_key, object_id, object_type, data) do
    ConCache.get_or_store(@event_targets, {realm_name, object_id, object_type}, fn ->
      fetch_data_triggers(realm_name, object_id, object_type, data)
    end)
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

    data = %{data | data_triggers: %{}}

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

  def trigger_subject(:device_trigger, trigger) do
    %ProtobufDeviceTrigger{device_id: hw_id, group_name: group} = trigger

    case {hw_id, group} do
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

  def trigger_subject(:data_trigger, trigger) do
    case trigger do
      %{device_id: any_device, group_name: nil, interface_name: "*"}
      when any_device in [nil, "*"] ->
        {:ok, :any_interface}

      %{device_id: any_device, group_name: nil, interface_name: name, interface_major: major}
      when any_device in [nil, "*"] ->
        interface_id = CQLUtils.interface_id(name, major)
        {:ok, {:interface, interface_id}}

      %{device_id: any_device, group_name: group, interface_name: "*"}
      when any_device in [nil, "*"] ->
        {:ok, {:group_and_any_interface, group}}

      %{device_id: any_device, group_name: group, interface_name: name, interface_major: major}
      when any_device in [nil, "*"] ->
        interface_id = CQLUtils.interface_id(name, major)
        {:ok, {:group_and_interface, group, interface_id}}

      %{device_id: hw_id, interface_name: "*"} ->
        with {:ok, device_id} <- Device.decode_device_id(hw_id, allow_extended_id: true) do
          {:ok, {:device_and_any_interface, device_id}}
        end

      %{device_id: hw_id, interface_name: name, interface_major: major} ->
        interface_id = CQLUtils.interface_id(name, major)

        with {:ok, device_id} <- Device.decode_device_id(hw_id, allow_extended_id: true) do
          {:ok, {:device_and_interface, device_id, interface_id}}
        end
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
