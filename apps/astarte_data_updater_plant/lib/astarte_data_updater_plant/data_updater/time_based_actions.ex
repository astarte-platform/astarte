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

defmodule Astarte.DataUpdaterPlant.TimeBasedActions do
  @moduledoc """
  This module implements the time-based actions that need to be executed periodically for each device in the DataUpdaterPlant.
  """
  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater.Core
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias Astarte.DataUpdaterPlant.RPC.VMQPlugin

  require Logger

  @groups_lifespan_decimicroseconds 60 * 10 * 1000 * 10_000
  @deletion_refresh_lifespan_decimicroseconds 60 * 10 * 1000 * 10_000
  @datastream_maximum_retention_refresh_lifespan_decimicroseconds 60 * 10 * 1000 * 10_000

  def execute_time_based_actions(state, timestamp) do
    if state.connected && state.last_seen_message > 0 do
      # timestamps are handled as microseconds*10, so we need to divide by 10 when saving as a
      # metric for a coherent data
      :telemetry.execute(
        [:astarte, :data_updater_plant, :service, :connected_devices],
        %{duration: Integer.floor_div(timestamp - state.last_seen_message, 10)},
        %{realm: state.realm, status: :ok}
      )
    end

    state
    |> Map.put(:last_seen_message, timestamp)
    |> reload_groups_on_expiry(timestamp)
    |> purge_expired_interfaces(timestamp)
    |> reload_device_deletion_status_on_expiry(timestamp)
    |> reload_datastream_maximum_storage_retention_on_expiry(timestamp)
  end

  def reload_groups_on_expiry(state, timestamp) do
    if state.last_groups_refresh + @groups_lifespan_decimicroseconds <= timestamp do
      # TODO this could be a bang!
      {:ok, groups} = Queries.get_device_groups(state.realm, state.device_id)

      %{state | last_groups_refresh: timestamp, groups: groups}
    else
      state
    end
  end

  def purge_expired_interfaces(state, timestamp) do
    expired =
      Enum.take_while(state.interfaces_by_expiry, fn {expiry, _interface} ->
        expiry <= timestamp
      end)

    new_interfaces_by_expiry = Enum.drop(state.interfaces_by_expiry, length(expired))

    interfaces_to_drop_list =
      for {_exp, iface} <- expired do
        iface
      end

    state
    |> Core.Interface.forget_interfaces(interfaces_to_drop_list)
    |> Map.put(:interfaces_by_expiry, new_interfaces_by_expiry)
  end

  def reload_device_deletion_status_on_expiry(state, timestamp) do
    if state.last_deletion_in_progress_refresh + @deletion_refresh_lifespan_decimicroseconds <=
         timestamp do
      new_state = maybe_start_device_deletion(state, timestamp)
      %State{new_state | last_deletion_in_progress_refresh: timestamp}
    else
      state
    end
  end

  defp maybe_start_device_deletion(state, timestamp) do
    %State{realm: realm, device_id: device_id} = state

    if should_start_device_deletion?(realm, device_id) do
      encoded_device_id = Device.encode_device_id(device_id)

      :ok = force_device_deletion_from_broker(realm, encoded_device_id)
      new_state = Core.Device.set_device_disconnected(state, timestamp)

      Logger.info("Stop handling data from device in deletion, device_id #{encoded_device_id}")

      Queries.ensure_replicated_group_information(realm, device_id)

      # It's ok to repeat that, as we always write ⊤
      Queries.ack_start_device_deletion(realm, device_id)

      %State{new_state | discard_messages: true}
    else
      state
    end
  end

  defp should_start_device_deletion?(realm_name, device_id) do
    case Queries.check_device_deletion_in_progress(realm_name, device_id) do
      {:ok, true} ->
        true

      {:ok, false} ->
        false

      {:error, reason} ->
        Logger.warning(
          "Cannot check device deletion status for #{inspect(device_id)}, reason #{inspect(reason)}",
          tag: "should_start_device_deletion_fail"
        )

        false
    end
  end

  defp force_device_deletion_from_broker(realm, encoded_device_id) do
    Logger.info("Disconnecting device to be deleted, device_id #{encoded_device_id}")

    case VMQPlugin.delete(realm, encoded_device_id) do
      # Successfully disconnected
      :ok ->
        :ok

      # Not found means it was already disconnected, succeed anyway
      {:error, :not_found} ->
        :ok

      # Some other error, return it
      {:error, reason} ->
        {:error, reason}
    end
  end

  def reload_datastream_maximum_storage_retention_on_expiry(state, timestamp) do
    if state.last_datastream_maximum_retention_refresh +
         @datastream_maximum_retention_refresh_lifespan_decimicroseconds <=
         timestamp do
      # TODO this could be a bang!
      case Queries.get_datastream_maximum_storage_retention(state.realm) do
        {:ok, ttl} ->
          %State{
            state
            | datastream_maximum_storage_retention: ttl,
              last_datastream_maximum_retention_refresh: timestamp
          }

        {:error, _reason} ->
          Logger.warning(
            "Failed to load last_datastream_maximum_retention_refresh, keeping old one",
            tag: "last_datastream_maximum_retention_refresh_fail"
          )

          state
      end
    else
      state
    end
  end
end
