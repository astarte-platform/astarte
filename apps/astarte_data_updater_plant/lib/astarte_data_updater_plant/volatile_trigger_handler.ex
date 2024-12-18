# Copyright 2024 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule Astarte.DataUpdaterPlant.VolatileTriggerHandler do
  alias Astarte.Core.Device
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataAccess.Database
  alias Astarte.RPC.Protocol.DataUpdaterPlant.InstallVolatileTrigger
  alias Astarte.RPC.Protocol.DataUpdaterPlant.DeleteVolatileTrigger
  alias Mississippi.Consumer.DataUpdater
  require Logger

  @spec install_volatile_trigger(InstallVolatileTrigger.t()) :: :ok | {:error, reason :: atom()}
  def install_volatile_trigger(install_volatile_trigger) do
    %InstallVolatileTrigger{
      realm_name: realm_name,
      device_id: encoded_device_id
    } = install_volatile_trigger

    with :ok <- verify_device_exists(realm_name, encoded_device_id),
         {:ok, device_id} <- decode_device_id(encoded_device_id) do
      sharding_key = {realm_name, device_id}

      {:ok, du_pid} = DataUpdater.get_data_updater_process(sharding_key)

      DataUpdater.handle_signal(
        du_pid,
        {:handle_install_volatile_trigger, install_volatile_trigger}
      )
    end
  end

  @spec delete_volatile_trigger(DeleteVolatileTrigger.t()) :: :ok | {:error, reason :: atom()}
  def delete_volatile_trigger(delete_volatile_trigger) do
    %DeleteVolatileTrigger{
      realm_name: realm_name,
      device_id: encoded_device_id
    } = delete_volatile_trigger

    with :ok <- verify_device_exists(realm_name, encoded_device_id),
         {:ok, device_id} <- decode_device_id(encoded_device_id) do
      sharding_key = {realm_name, device_id}

      {:ok, du_pid} = DataUpdater.get_data_updater_process(sharding_key)

      DataUpdater.handle_signal(
        du_pid,
        {:handle_delete_volatile_trigger, delete_volatile_trigger}
      )
    end
  end

  defp decode_device_id(encoded_device_id) do
    case Device.decode_device_id(encoded_device_id) do
      {:ok, device_id} ->
        {:ok, device_id}

      {:error, :extended_id_not_allowed} ->
        Logger.info("Received unexpected extended device id: #{encoded_device_id}")
        {:error, :extended_id_not_allowed}

      {:error, :invalid_device_id} ->
        Logger.info("Received invalid device id: #{encoded_device_id}")
        {:error, :invalid_device_id}
    end
  end

  defp verify_device_exists(realm_name, encoded_device_id) do
    with {:ok, decoded_device_id} <- Device.decode_device_id(encoded_device_id),
         {:ok, client} <- Database.connect(realm: realm_name),
         {:ok, exists?} <- Queries.check_device_exists(client, decoded_device_id) do
      if exists? do
        :ok
      else
        _ =
          Logger.warning(
            "Device #{encoded_device_id} in realm #{realm_name} does not exist.",
            tag: "device_does_not_exist"
          )

        {:error, :device_does_not_exist}
      end
    end
  end
end
