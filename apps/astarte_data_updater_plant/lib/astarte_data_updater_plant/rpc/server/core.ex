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

  alias Astarte.DataAccess.Interface
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.RPC.Replica

  def install_trigger(realm_name, tagged_simple_trigger, target, policy) do
    with {:ok, data} <- find_trigger_data(realm_name, tagged_simple_trigger) do
      message = {:install_trigger, {realm_name, tagged_simple_trigger, target, policy, data}}
      Replica.send_all_replicas(message)
    end
  end

  def install_volatile_trigger(volatile_trigger) do
    %{
      realm_name: realm,
      device_id: device_id,
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
          {:handle_install_volatile_trigger, parent_id, trigger_id, simple_trigger,
           trigger_target}
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

  defp find_trigger_data(realm_name, tagged_simple_trigger) do
    case tagged_simple_trigger.simple_trigger_container.simple_trigger do
      {:device_trigger, _} ->
        {:ok, %{}}

      {:data_trigger, %{interface_name: "*"}} ->
        {:ok, %{}}

      {:data_trigger, %{match_path: "/*"}} ->
        {:ok, %{}}

      {:data_trigger, %{interface_name: name, interface_major: major}} ->
        load_interface(realm_name, name, major)
    end
  end

  @spec load_interface(String.t(), String.t(), non_neg_integer()) ::
          {:ok, %{interface_ids_to_name: map(), interfaces: map()}}
          | {:error, :interface_not_found}
  defp load_interface(realm_name, interface_name, interface_major) do
    with {:ok, descriptor} <-
           Interface.fetch_interface_descriptor(realm_name, interface_name, interface_major) do
      result = %{
        interface_ids_to_name: %{descriptor.interface_id => descriptor.name},
        interfaces: %{descriptor.name => descriptor}
      }

      {:ok, result}
    end
  end
end
