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

defmodule Astarte.DataUpdaterPlant.RPC.Core.Trigger do
  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.RPC.Queries
  
  require Logger

  def get_trigger_installation_scope(simple_trigger) do
    case simple_trigger do
      {:data_trigger, %Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger{} = data_trigger} ->
        cond do
          Map.has_key?(data_trigger, :group_name) and not is_nil(data_trigger.group_name) ->
            {:data_trigger_group, data_trigger.group_name}

          Map.has_key?(data_trigger, :device_id) and not is_nil(data_trigger.device_id) ->
            {:ok, decoded_device_id} = Device.decode_device_id(data_trigger.device_id)
            {:device, decoded_device_id}
           

          true ->
            {:all, nil}
        end

      {:device_trigger,
       %Astarte.Core.Triggers.SimpleTriggersProtobuf.DeviceTrigger{device_id: device_id}} ->
          {:ok, decoded_device_id} = Device.decode_device_id(device_id)
          {:device, decoded_device_id}
    end
  end

  def get_pids_of_grouped_devices(realm, group_name) do
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

  def get_pids_for_realm(realm) do
    Horde.Registry.select(
      Registry.DataUpdater,
      [{{{realm, :"$1"}, :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}]
    )
  end

  def get_pids_of_devices_to_notify(realm, scope) do
    case scope do
      {:all, nil} ->
        get_pids_for_realm(realm)

      {:data_trigger_group, group_name} ->
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

  def install_persistent_triggers(triggers, state) do
    Logger.info("Received request to install persistent triggers ...")
    Logger.info("Triggers details: #{inspect(triggers)}")
    %{realm: realm, triggers: triggers, trigger_target: trigger_target} = triggers

    results =
      triggers
      |> Enum.map(fn %{simple_trigger: simple_trigger} ->
        scope = get_trigger_installation_scope(simple_trigger)
        Logger.info("Determined scope for trigger installation: #{inspect(scope)}")

        devices_to_notify = get_pids_of_devices_to_notify(realm, scope)
        Logger.info("Devices to notify: #{inspect(devices_to_notify)}")

        devices_to_notify
        |> Task.async_stream(
          fn {device_id, pid} ->
            Logger.info("Processing trigger installation for device #{Device.encode_device_id(device_id)}...}")

            case GenServer.call(pid, {:handle_install_persistent_triggers, triggers, trigger_target}) do
              {:error, error} ->
                Logger.error("Error #{inspect(error)} while processing device #{Device.encode_device_id(device_id)} for `install_persistent_triggers`.")

              _ ->
                Logger.info("Trigger installed successfully for device #{Device.encode_device_id(device_id)}.")
            end
          end,
          max_concurrency: 10,
          timeout: :infinity
        )
        |> Enum.to_list()
      end)

    {:reply, {:ok, results}, state}
  end
end
