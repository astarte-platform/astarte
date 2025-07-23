#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule AstarteE2E do
  @moduledoc """
  Documentation for `AstarteE2E`.
  """

  require Logger

  alias Astarte.Device
  alias AstarteE2E.{Client, Config, Utils}

  def perform_check(realm, device_id) do
    with {:ok, device_pid} <- fetch_device_pid(realm, device_id),
         {:ok, interface_names} <- fetch_interface_names(),
         :ok <- Device.wait_for_connection(device_pid),
         :ok <- Client.wait_for_connection(realm, device_id) do
      timestamp = :erlang.monotonic_time(:millisecond)
      path = "/correlationId"

      task_list =
        Enum.map(interface_names, fn interface_name ->
          value = Utils.random_string()

          args = [
            interface_name: interface_name,
            device_id: device_id,
            device_pid: device_pid,
            path: path,
            value: value,
            timestamp: timestamp,
            realm: realm
          ]

          Task.async(AstarteE2E, :push_and_verify, [args])
        end)

      tasks_with_results = Task.yield_many(task_list, :infinity)

      Enum.reduce_while(tasks_with_results, :ok, fn {_task, result}, _acc ->
        case result do
          {:ok, :ok} ->
            {:cont, :ok}

          {:ok, {:error, reason}} ->
            {:halt, {:error, reason}}

          {:exit, reason} ->
            {:halt, {:error, reason}}

          nil ->
            {:halt, {:error, :timeout}}
        end
      end)
    end
  end

  def push_and_verify(args) do
    interface_name = Keyword.fetch!(args, :interface_name)
    device_id = Keyword.fetch!(args, :device_id)
    device_pid = Keyword.fetch!(args, :device_pid)
    path = Keyword.fetch!(args, :path)
    value = Keyword.fetch!(args, :value)
    timestamp = Keyword.fetch!(args, :timestamp)
    realm = Keyword.fetch!(args, :realm)

    with :ok <- push_data(device_pid, interface_name, path, value),
         :telemetry.execute([:astarte_end_to_end, :messages, :sent], %{}, %{}),
         :ok <-
           Client.verify_device_payload(
             realm,
             device_id,
             interface_name,
             path,
             value,
             timestamp
           ) do
      :ok
    end
  end

  defp push_data(
         device_pid,
         "org.astarte-platform.e2etest.SimpleDatastream" = interface_name,
         path,
         value
       ) do
    Device.send_datastream(device_pid, interface_name, path, value)
  end

  defp push_data(
         device_pid,
         "org.astarte-platform.e2etest.SimpleProperties" = interface_name,
         path,
         value
       ) do
    Device.set_property(device_pid, interface_name, path, value)
  end

  defp fetch_device_pid(realm, device_id) do
    case Device.get_pid(realm, device_id) do
      nil -> {:error, :unregistered_device}
      pid -> {:ok, pid}
    end
  end

  defp fetch_interface_names do
    with {:ok, interface_path} <- Config.standard_interface_provider(),
         {:ok, raw_interfaces_list} <- File.ls(interface_path) do
      interface_names =
        Enum.reduce(raw_interfaces_list, [], fn raw_interface, acc ->
          interface_name =
            raw_interface
            |> String.trim(".json")

          [interface_name | acc]
        end)

      {:ok, interface_names}
    else
      error ->
        Logger.error("Interfaces names cannot be retrieved. Reason: #{inspect(error)}")
    end
  end
end
