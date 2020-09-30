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

  def perform_check do
    with {:ok, device_pid} <- fetch_device_pid(Config.realm!(), Config.device_id!()),
         {:ok, interface_names} <- fetch_interface_names(),
         :ok <- Device.wait_for_connection(device_pid) do
      realm = Config.realm!()
      device_id = Config.device_id!()

      Enum.reduce_while(interface_names, [], fn interface_name, _acc ->
        timestamp = :erlang.monotonic_time(:millisecond)
        value = Utils.random_string()
        path = "/correlationId"

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
          {:cont, :ok}
        else
          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)
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
