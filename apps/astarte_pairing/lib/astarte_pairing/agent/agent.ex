#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.Agent do
  @moduledoc """
  The Agent context.
  """

  alias Astarte.Core.Device
  alias Astarte.Pairing.Agent.DeviceRegistrationRequest
  alias Astarte.Pairing.Agent.DeviceRegistrationResponse
  alias Astarte.Pairing.Engine
  alias Astarte.Pairing.Config

  alias Astarte.Core.Triggers.SimpleEvents.DeviceRegisteredEvent
  alias Astarte.Events.Triggers
  alias Astarte.Events.TriggersHandler
  @cache_name Config.trigger_cache_name!()

  def register_device(realm, attrs \\ %{}) do
    changeset =
      %DeviceRegistrationRequest{}
      |> DeviceRegistrationRequest.changeset(attrs)

    with {:ok,
          %DeviceRegistrationRequest{hw_id: hw_id, initial_introspection: initial_introspection}} <-
           Ecto.Changeset.apply_action(changeset, :insert),
         initial_introspection =
           Enum.map(initial_introspection, fn {interface_name,
                                               %{"major" => major, "minor" => minor}} ->
             %{
               interface_name: interface_name,
               major_version: major,
               minor_version: minor
             }
           end),
         {:ok, credentials_secret} <-
           Engine.register_device(realm, hw_id, initial_introspection: initial_introspection) do
      dispatch_device_registration_trigger(realm, hw_id)

      {:ok, %DeviceRegistrationResponse{credentials_secret: credentials_secret}}
    end
  end

  def unregister_device(realm, device_id) do
    with {:ok, _} <- Device.decode_device_id(device_id) do
      Engine.unregister_device(realm, device_id)
    end
  end

  defp dispatch_device_registration_trigger(realm_name, hw_id) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    event_key = :on_device_registered
    event_type = :device_registered_event
    {:ok, device_id} = Device.decode_device_id(hw_id, allow_extended_id: true)

    find_targets(realm_name, device_id, event_key)
    |> dispatch_all(realm_name, hw_id, timestamp, event_type, %DeviceRegisteredEvent{})
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
  end

  defp find_targets(realm_name, device_id, event_type) do
    load_triggers(realm_name)
    |> Triggers.find_trigger_targets_for_device(realm_name, device_id, event_type)
  end

  defp load_triggers(realm_name) do
    ConCache.get_or_store(@cache_name, realm_name, fn ->
      Triggers.fetch_realm_device_trigger(realm_name)
    end)
  end
end
