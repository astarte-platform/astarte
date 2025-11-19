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
        ) :: :ok | {:error, :interface_not_found | :invalid_match_path | :invalid_device_id}
  def install_volatile_trigger(realm_name, deserialized_volatile_trigger, data \\ %{}) do
    {{trigger_type, trigger}, target} = deserialized_volatile_trigger

    with {:ok, event_key, new_trigger} <-
           Core.get_trigger_with_event_key(data, trigger_type, trigger),
         {:ok, subject} <- Core.trigger_subject(trigger_type, trigger) do
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
    Returns the list of targets for a device event.
  """
  @spec find_device_trigger_targets(
          String.t(),
          Astarte.DataAccess.UUID.t(),
          [String.t()] | nil,
          Core.device_event_key()
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

  @doc """
    Returns the list of targets for an interface related device event
  """
  @spec find_interface_event_device_trigger_targets(
          String.t(),
          Astarte.DataAccess.UUID.t(),
          [String.t()] | nil,
          :on_interface_added | :on_interface_removed | :on_interface_minor_updated,
          Astarte.DataAccess.UUID.t()
        ) :: [Core.target_and_policy()]
  def find_interface_event_device_trigger_targets(
        realm_name,
        device_id,
        groups \\ nil,
        event,
        interface_id
      ) do
    device_groups = groups || Queries.get_device_groups(realm_name, device_id)

    [{event, :any_interface}, {event, interface_id}]
    |> Enum.map(fn event_key ->
      Cache.find_device_trigger_targets(realm_name, device_id, device_groups, event_key)
    end)
    |> Enum.concat()
  end

  @doc """
    Returns the full list of targets for data events on an interface and endpoint.
  """
  @spec find_all_data_trigger_targets(
          String.t(),
          Astarte.DataAccess.UUID.t(),
          [String.t()],
          Core.data_trigger_event(),
          Astarte.DataAccess.UUID.t(),
          Astarte.DataAccess.UUID.t(),
          Core.fetch_triggers_data()
        ) :: [Core.target_and_policy()]
  def find_all_data_trigger_targets(
        realm_name,
        device_id,
        groups,
        event,
        interface_id,
        endpoint_id,
        data
      ) do
    [
      {event, :any_interface, :any_endpoint},
      {event, interface_id, :any_endpoint},
      {event, interface_id, endpoint_id}
    ]
    |> Enum.map(fn event_key ->
      Cache.find_data_trigger_targets(realm_name, device_id, groups, event_key, data)
    end)
    |> Enum.concat()
  end

  @doc """
    Returns the full list of targets for data events on an interface and endpoint with a path and value.
  """
  @spec find_all_data_trigger_targets(
          String.t(),
          Astarte.DataAccess.UUID.t(),
          [String.t()],
          Core.data_trigger_event(),
          Astarte.DataAccess.UUID.t(),
          Astarte.DataAccess.UUID.t(),
          String.t(),
          term(),
          Core.fetch_triggers_data()
        ) :: [Core.target_and_policy()]
  def find_all_data_trigger_targets(
        realm_name,
        device_id,
        groups,
        event,
        interface_id,
        endpoint_id,
        path,
        value \\ nil,
        data
      ) do
    path_tokens = path |> String.split("/") |> Enum.drop(1)

    [
      {event, :any_interface, :any_endpoint},
      {event, interface_id, :any_endpoint},
      {event, interface_id, endpoint_id}
    ]
    |> Enum.map(fn event_key ->
      Cache.find_data_trigger_targets(
        realm_name,
        device_id,
        groups,
        event_key,
        path_tokens,
        value,
        data
      )
    end)
    |> Enum.concat()
  end

  defdelegate find_data_trigger_targets(realm_name, device_id, groups, event_key, data), to: Cache

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
        path,
        value \\ nil,
        data
      ) do
    path_tokens = path |> String.split("/") |> Enum.drop(1)

    Cache.find_data_trigger_targets(
      realm_name,
      device_id,
      groups,
      event_key,
      path_tokens,
      value,
      data
    )
  end

  defdelegate deserialize_simple_trigger(trigger), to: Core
end
