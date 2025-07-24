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

defmodule AstarteE2E.Application do
  use Application

  alias AstarteE2E.Config
  alias AstarteE2E.Device
  alias AstarteE2E.ServiceNotifier

  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting AstarteE2E application.", tag: "application_start")

    with :ok <- Config.validate(),
         {:ok, realm} <- Config.realm(),
         {:ok, interfaces} <- default_interfaces() do
      device_id = Astarte.Core.Device.random_device_id()
      device_opts = [realm: realm, device_id: device_id, interfaces: interfaces]

      children = [
        {Registry, keys: :unique, name: Registry.AstarteE2E},
        AstarteE2EWeb.Telemetry,
        {ServiceNotifier, Config.notifier_opts()},
        {Device, device_opts}
      ]

      opts = [strategy: :one_for_one, name: __MODULE__]

      Supervisor.start_link(children, opts)
    else
      {:error, reason} ->
        Logger.warning(
          "Configuration incomplete. Unable to start process with reason: #{reason}."
        )

        {:shutdown, reason}
    end
  end

  defp default_interfaces() do
    with {:ok, standard_interface_provider} <- Config.standard_interface_provider(),
         {:ok, interface_files} <- File.ls(standard_interface_provider) do
      interface_files = interface_files |> Enum.map(&Path.join(standard_interface_provider, &1))
      read_interface_files(interface_files)
    end
  end

  defp read_interface_files(interface_files) do
    Enum.reduce_while(interface_files, {:ok, []}, fn interface_file, {:ok, interfaces} ->
      with {:ok, interface_json} <- File.read(interface_file),
           {:ok, interface} <- Jason.decode(interface_json) do
        {:cont, {:ok, [interface | interfaces]}}
      else
        error ->
          Logger.error("Error reading interface: #{interface_file}")
          {:halt, error}
      end
    end)
  end
end
