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

defmodule AstarteE2E.VolatileTriggerRoundtrip.Executor do
  use GenServer

  alias AstarteE2E.Config
  alias AstarteE2E.Device
  alias AstarteE2E.VolatileTriggerRoundtrip.Scheduler

  require Logger

  def name, do: "device data volatile trigger roundtrip"

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg)
  end

  @impl GenServer
  def init(opts) do
    Process.flag(:trap_exit, true)

    with {:ok, realm} <- Config.realm() do
      interfaces = Keyword.get(opts, :interfaces)
      device_id = Astarte.Core.Device.random_device_id()

      device_opts = [realm: realm, device_id: device_id, interfaces: interfaces]
      encoded_id = Astarte.Core.Device.encode_device_id(device_id)

      scheduler_opts =
        Config.scheduler_opts()
        |> Keyword.put(:device_id, encoded_id)
        |> Keyword.put(:interfaces, interfaces)

      {:ok, device} = Device.start_link(device_opts)
      {:ok, scheduler} = Scheduler.start_link(scheduler_opts)

      {:ok, %{device: device, scheduler: scheduler}}
    else
      error -> {:stop, error, nil}
    end
  end

  @impl GenServer
  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end
end
