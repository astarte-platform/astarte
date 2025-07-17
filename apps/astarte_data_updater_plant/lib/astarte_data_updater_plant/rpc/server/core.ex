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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.RPC.Server.Core do
  @moduledoc """
  The core logic handling the DataUpdaterPlant.RPC.Server
  """
  require Logger
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.RPC.Queries
  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.RPC.Queries

  def install_volatile_trigger(volatile_trigger) do
    %{
      realm_name: realm,
      device_id: device_id,
      object_id: object_id,
      object_type: object_type,
      parent_id: parent_id,
      simple_trigger_id: trigger_id,
      simple_trigger: simple_trigger,
      trigger_target: trigger_target
    } = volatile_trigger

    DataUpdater.with_dup_and_message_tracker(
      realm,
      device_id,
      fn dup, _message_tracker ->
        GenServer.call(
          dup,
          {:handle_install_volatile_trigger, object_id, object_type, parent_id, trigger_id,
           simple_trigger, trigger_target}
        )
      end
    )
  end

  def delete_volatile_trigger(delete_request) do
    %{
      realm_name: realm,
      device_id: device_id,
      trigger_id: trigger_id
    } = delete_request

    DataUpdater.with_dup_and_message_tracker(
      realm,
      device_id,
      fn dup, _message_tracker ->
        GenServer.call(
          dup,
          {:handle_delete_volatile_trigger, trigger_id}
        )
      end
    )
  end

  defp get_trigger_installation_scope(trigger_map) do
    case trigger_map do
      %{simple_trigger: {:data_trigger, %Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger{} = data_trigger}} ->
        cond do
          not is_nil(data_trigger.group_name) ->
            {:device_group, data_trigger.group_name}

          not is_nil(data_trigger.device_id) ->
            {:ok, decoded_device_id} = Device.decode_device_id(data_trigger.device_id)
            {:device, decoded_device_id}

          true ->
            {:all_devices}
        end

      %{simple_trigger: {:device_trigger, %Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger{device_id: device_id}}} ->
        {:ok, decoded_device_id} = Device.decode_device_id(device_id)
        {:device, decoded_device_id}
    end
  end

  defp get_pids_of_grouped_devices(realm, group_name) do
  grouped_devices = Queries.fetch_grouped_devices(realm, group_name)

  if grouped_devices == [] do
    Logger.warning(
      "No devices found in group #{inspect(group_name)} for realm #{inspect(realm)}."
    )

    []
  else
    results_one = Horde.Registry.select(
      Registry.DataUpdater,
      [
        {{{realm, :"$2"}, :"$3", :_}, [], [{{:"$2", :"$3"}}]}
      ]
    )

    filtered_results = Enum.filter(results_one, fn {device_id, _pid} ->
      device_id in grouped_devices
    end)

    filtered_results
  end
end

  defp get_pids_for_realm(realm) do
    Horde.Registry.select(
      Registry.DataUpdater,
      [{{{realm, :"$1"}, :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}]
    )
  end

  defp get_pids_of_devices_to_notify(realm, scope) do
    case scope do
      {:all_devices} ->
        get_pids_for_realm(realm)

      {:device_group, group_name} ->
        get_pids_of_grouped_devices(realm, group_name)

      {:device, device_id} ->

        case Horde.Registry.lookup(Registry.DataUpdater, {realm, device_id}) do
          [] ->
            Logger.warning(
              "No process found for device #{inspect(device_id)} in realm #{inspect(realm)}."
            )

            []

          [{pid, _value} | _] ->
          [{device_id, pid}] 
        end

      {:data_trigger_device, device_id} ->
        case Horde.Registry.lookup(Registry.DataUpdater, {realm, device_id}) do
          [] ->
            Logger.warning(
              "No process found for data trigger device #{inspect(device_id)} in realm #{inspect(realm)}."
            )

            []

          [{pid, _value} | _] ->
          [{device_id, pid}]
        end

      _ ->
        Logger.error("Unknown scope for trigger installation detected: #{inspect(scope)}")
        []
    end
  end

  def install_persistent_triggers(triggers) do
    Logger.debug("Received request to install persistent triggers: #{inspect(triggers)}")

    %{realm: realm, triggers: triggers, trigger_target: trigger_target} = triggers

    scope = get_trigger_installation_scope(List.first(triggers))
    Logger.debug("Determined scope for triggers installation: #{inspect(scope)}")

    devices_to_notify = get_pids_of_devices_to_notify(realm, scope)
    Logger.debug("Devices to notify: #{inspect(devices_to_notify)}")

    # Sending trigger (batch of simple_triggers) to each device
    results =
        devices_to_notify
      |> Task.async_stream(
        fn {device_id, pid} ->
          Logger.debug("Processing trigger installation for device #{Device.encode_device_id(device_id)}...")

          case GenServer.call(pid, {:handle_install_persistent_triggers, triggers, trigger_target}) do
            {:error, error} ->
              Logger.error("Error #{inspect(error)} while processing device #{Device.encode_device_id(device_id)} for `install_persistent_triggers`.")

            _ ->
              Logger.debug("Trigger installed successfully for device #{Device.encode_device_id(device_id)}.")
          end
        end,
        max_concurrency: 250,
        timeout: :infinity
      )
      |> Enum.to_list()

    {:ok, results}
  end

end
