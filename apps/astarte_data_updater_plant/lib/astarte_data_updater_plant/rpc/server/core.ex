#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Mississippi.Consumer.DataUpdater

  def install_volatile_trigger(volatile_trigger) do
    %{
      realm_name: realm,
      device_id: encoded_device_id,
      parent_id: parent_id,
      simple_trigger_id: trigger_id,
      simple_trigger: simple_trigger,
      trigger_target: trigger_target
    } = volatile_trigger

    signal =
      {:install_volatile_trigger, parent_id, trigger_id, simple_trigger, trigger_target}

    signal_existing_device(realm, encoded_device_id, signal)
  end

  def delete_volatile_trigger(delete_request) do
    %{
      realm_name: realm,
      device_id: encoded_device_id,
      trigger_id: trigger_id
    } = delete_request

    signal = {:delete_volatile_trigger, trigger_id}
    signal_existing_device(realm, encoded_device_id, signal)
  end

  def start_device_deletion(realm, encoded_device_id, timestamp) do
    signal = {:start_device_deletion, timestamp}
    signal_existing_device(realm, encoded_device_id, signal)
  end

  defp signal_existing_device(realm, encoded_device_id, signal) do
    with {:ok, device_id} <- Device.decode_device_id(encoded_device_id),
         :ok <- verify_device_exists(realm, device_id),
         {:ok, dup} <- DataUpdater.get_data_updater_process({realm, device_id}) do
      DataUpdater.handle_signal(dup, signal)
    end
  end

  defp verify_device_exists(realm_name, device_id) do
    case Queries.check_device_exists(realm_name, device_id) do
      {:ok, true} ->
        :ok

      {:ok, false} ->
        encoded_device_id = Device.encode_device_id(device_id)

        "Device #{encoded_device_id} in realm #{realm_name} does not exist."
        |> Logger.warning(tag: "device_does_not_exist")

        {:error, :device_does_not_exist}

      error ->
        error
    end
  end
end
