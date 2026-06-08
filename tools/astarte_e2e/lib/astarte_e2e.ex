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

  use ExUnitProperties

  alias Astarte.Core.Mapping
  alias Astarte.Device
  alias AstarteE2E.{Client, Utils}

  def publish_data(device_pid, datastream_interface, properties_interface) do
    datastream_name = datastream_interface.name
    properties_name = properties_interface.name

    datastreams = Enum.map(1..5, fn _ -> Utils.random_string() end)
    property = Utils.random_string()

    datastream_path =
      datastream_interface.mappings |> hd() |> Map.fetch!(:endpoint) |> path_from_endpoint()

    properties_path =
      properties_interface.mappings |> hd() |> Map.fetch!(:endpoint) |> path_from_endpoint()

    with :ok <- publish_datastreams(device_pid, datastream_name, datastream_path, datastreams),
         :ok <- Device.set_property(device_pid, properties_name, properties_path, property) do
      {:ok, %{datastreams: datastreams, property: property}}
    end
  end

  defp publish_datastreams(device_pid, datastream_interface, path, datastreams) do
    Enum.reduce_while(datastreams, :ok, fn datastream, :ok ->
      case Device.send_datastream(device_pid, datastream_interface, path, datastream) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  def perform_check(realm, device_id, interfaces) do
    with {:ok, device_pid} <- fetch_device_pid(realm, device_id),
         :ok <- Device.wait_for_connection(device_pid),
         :ok <- Client.wait_for_connection(realm, device_id) do
      timestamp = :erlang.monotonic_time(:millisecond)

      task_list =
        Enum.map(interfaces, fn interface ->
          value = Utils.random_string()
          path = interface.mappings |> hd() |> Map.fetch!(:endpoint) |> path_from_endpoint()

          args = [
            interface: interface,
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
    interface = Keyword.fetch!(args, :interface)
    device_id = Keyword.fetch!(args, :device_id)
    device_pid = Keyword.fetch!(args, :device_pid)
    path = Keyword.fetch!(args, :path)
    value = Keyword.fetch!(args, :value)
    timestamp = Keyword.fetch!(args, :timestamp)
    realm = Keyword.fetch!(args, :realm)

    interface_name = interface.name

    with :ok <- push_data(device_pid, interface, path, value),
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
         %{type: :datastream, name: name},
         path,
         value
       ) do
    Device.send_datastream(device_pid, name, path, value)
  end

  defp push_data(
         device_pid,
         %{type: :properties, name: name},
         path,
         value
       ) do
    Device.set_property(device_pid, name, path, value)
  end

  defp fetch_device_pid(realm, device_id) do
    case Device.get_pid(realm, device_id) do
      nil -> {:error, :unregistered_device}
      pid -> {:ok, pid}
    end
  end

  defp path_from_endpoint(endpoint) do
    endpoint
    |> String.split("/")
    |> Enum.map(fn token ->
      if Mapping.is_placeholder?(token) do
        Utils.random_string()
      else
        token
      end
    end)
    |> Enum.join("/")
  end
end
